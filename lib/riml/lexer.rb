# encoding: utf-8

require 'strscan'
require File.expand_path('../constants', __FILE__)
require File.expand_path('../errors', __FILE__)

module Riml
  class Lexer
    include Riml::Constants

    SINGLE_LINE_COMMENT_REGEX = /\A[ \t\f]*"(.*)$/
    OPERATOR_REGEX = /\A#{Regexp.union(['||', '&&', '===', '+=', '-=', '.='] + COMPARISON_OPERATORS)}/
    INTERPOLATION_REGEX = /"([^"]*?)(\#\{([^"]*?)\})([^"]*?)"/m
    ANCHORED_INTERPOLATION_REGEX = /\A#{INTERPOLATION_REGEX}/m
    INTERPOLATION_SPLIT_REGEX = /(\#\{.*?\})/m

    attr_reader :tokens, :prev_token, :current_indent,
      :filename, :parser_info
    attr_accessor :lineno
    # for REPL
    attr_accessor :ignore_indentation_check

    def initialize(code, filename = nil, parser_info = false)
      code.chomp!
      @s = StringScanner.new(code)
      @filename = filename || COMPILED_STRING_LOCATION
      @parser_info = parser_info
      # array of doubles and triples: [tokenname, tokenval, lineno_to_add(optional)]
      # ex: [[:NEWLINE, "\n"]] OR [[:NEWLINE, "\n", 1]]
      @token_buf = []
      # array of doubles OR triples, depending if `@parser_info` is set to true
      # doubles: [tokenname, tokenval]
      # ex: [[:NEWLINE, "\n"], ...]
      # triples: [tokenname, tokenval, parser_info]
      # ex: [[:NEWLINE, "\n", { :lineno => 1, :filename => 'main.riml' }], ...]
      @tokens = []
      @prev_token = nil
      @lineno = 1
      @current_indent = 0
      @indent_pending = false
      @dedent_pending = false
      @in_function_declaration = false
    end

    def tokenize
      while next_token != nil; end
      @tokens
    end

    # TODO: fix this slow method
    def next_token
      while (buf_empty = @token_buf.empty?) && !@s.eos?
        tokenize_chunk
      end
      if !buf_empty
        token = @token_buf.shift
        if token.size == 3
          @lineno += token.pop
        end
        if @parser_info
          @tokens << decorate_token(token)
          @prev_token = token.first(2)
          return token
        else
          @tokens << token
          return @prev_token = token
        end
      end
      check_indentation unless ignore_indentation_check
      nil
    end

    def tokenize_chunk
      # deal with line continuations
      if cont = @s.scan(/\A\r?\n*[ \t\f]*\\/m)
        @lineno += cont.each_line.to_a.size - 1
        return
      end

      # all lines that start with ':' pass right through unmodified
      if (prev_token.nil? || prev_token[0] == :NEWLINE) && @s.scan(/\A[ \t\f]*:(.*)?$/)
        @token_buf << [:EX_LITERAL, @s[1]]
        return
      end

      if splat_var = @s.scan(/\Aa:\d+/)
        @token_buf << [:SCOPE_MODIFIER, 'a:'] << [:IDENTIFIER, splat_var[2..-1]]
      # the 'n' scope modifier is added by riml
      elsif @s.check(/\A([bwtglsavn]:)(\w|\{)/)
        @token_buf << [:SCOPE_MODIFIER, @s[1]]
        @s.pos += 2
      elsif scope_modifier_literal = @s.scan(/\A([bwtglsavn]:)/)
        @token_buf << [:SCOPE_MODIFIER_LITERAL, scope_modifier_literal]
      elsif special_var_prefix = (!@s.check(/\A&(\w:)?&/) && @s.scan(/\A(&(\w:)?|\$|@)/))
        @token_buf << [:SPECIAL_VAR_PREFIX, special_var_prefix.strip]
        if special_var_prefix == '@'
          next_char = @s.peek(1)
          if REGISTERS.include?(next_char)
            @token_buf << [:IDENTIFIER, next_char]
            @s.getch
          end
        else
          @expecting_identifier = true
        end
      elsif @s.scan(/\A(function)\(/)
        @token_buf << [:IDENTIFIER, @s[1]]
        @s.pos -= 1
      elsif identifier = @s.check(/\A[a-zA-Z_][\w#]*(\?|!)?/)
        # keyword identifiers
        if KEYWORDS.include?(identifier)
          if identifier.match(/\Afunction/)
            old_identifier = identifier.dup
            identifier.sub!(/function/, "def")
            @s.pos += (old_identifier.size - identifier.size)
          end

          if DEFINE_KEYWORDS.include?(identifier)
            @in_function_declaration = true
          end

          # strip '?' out of token names and replace '!' with '_bang'
          token_name = identifier.sub(/\?\Z/, "").sub(/!\Z/, "_bang").upcase
          track_indent_level(identifier)

          if VIML_END_KEYWORDS.include?(identifier)
            token_name = :END
          end

          @token_buf << [token_name.to_sym, identifier]

        elsif BUILTIN_COMMANDS.include?(identifier) && @s.peek(identifier.size + 1)[-1, 1] != '('
          @token_buf << [:BUILTIN_COMMAND, identifier]
        elsif RIML_FILE_COMMANDS.include? identifier
          @token_buf << [:RIML_FILE_COMMAND, identifier]
        elsif RIML_CLASS_COMMANDS.include? identifier
          @token_buf << [:RIML_CLASS_COMMAND, identifier]
        elsif VIML_COMMANDS.include?(identifier) && (prev_token.nil? || prev_token[0] == :NEWLINE)
          @s.pos += identifier.size
          until_eol = @s.scan(/.*$/).to_s
          @token_buf << [:EX_LITERAL, identifier << until_eol]
          return
        # method names and variable names
        else
          @token_buf << [:IDENTIFIER, identifier]
        end

        @s.pos += identifier.size

        parse_dict_vals!

      elsif @in_function_declaration && (splat_param = @s.scan(/\A(\.{3}|\*[a-zA-Z_]\w*)/))
        @token_buf << [:SPLAT_PARAM, splat_param]
      # splat in calling context. ex: super(*args) or super(*(args + other_args))
      elsif !@in_function_declaration && prev_token && prev_token[0] == '(' && @s.check(/\A\*(\w+|\()/)
        @token_buf << [:SPLAT_ARG, @s.getch]
      # integer (octal)
      elsif octal = @s.scan(/\A0[0-7]+/)
        @token_buf << [:NUMBER, octal]
      # integer (hex)
      elsif hex = @s.scan(/\A0[xX][0-9a-fA-F]+/)
        @token_buf << [:NUMBER, hex]
      # integer or float (decimal)
      elsif decimal = @s.scan(/\A[0-9]+(\.[0-9]+([eE][+-]?[0-9]+)?)?/)
        @token_buf << [:NUMBER, decimal]
      elsif interpolation = @s.scan(ANCHORED_INTERPOLATION_REGEX)
        # "hey there, #{name}" = "hey there, " . name
        parts = interpolation[1...-1].split(INTERPOLATION_SPLIT_REGEX)
        handle_interpolation(*parts)
      elsif (single_line_comment = @s.check(SINGLE_LINE_COMMENT_REGEX)) && (prev_token.nil? || prev_token[0] == :NEWLINE)
        @s.pos += single_line_comment.size
        @s.pos += 1 unless @s.eos? # consume newline
        @lineno += single_line_comment.each_line.to_a.size
      elsif inline_comment = @s.scan(/\A[ \t\f]*"[^"]*?$/)
        @lineno += inline_comment.each_line.to_a.size - 1
      elsif (str = lex_string_double)
        @token_buf << [:STRING_D, str]
      elsif @s.scan(/\A'(([^']|'')*)'/)
        @token_buf << [:STRING_S, @s[1]]
      elsif newlines = @s.scan(/\A([\r\n]+)/)
        # push only 1 newline
        @token_buf << [:NEWLINE, "\n"] unless prev_token && prev_token[0] == :NEWLINE

        # pending indents/dedents
        if @indent_pending
          @indent_pending = false
        elsif @dedent_pending
          @dedent_pending = false
        end
        if @in_function_declaration
          @in_function_declaration = false
        end

        @lineno += newlines.size
      # heredoc
      elsif @s.scan(%r{\A<<(.+?)\r?\n})
        pattern = @s[1]
        @s.check(%r|(.+?\r?\n)(#{Regexp.escape(pattern)})|m)
        heredoc_string = @s[1]
        @s.pos += (pattern.size + heredoc_string.size)
        heredoc_string.chomp!
        if heredoc_string =~ INTERPOLATION_REGEX || %Q("#{heredoc_string}") =~ INTERPOLATION_REGEX
          parts = heredoc_string.split(INTERPOLATION_SPLIT_REGEX)
          handle_interpolation(*parts)
        else
          @token_buf << [:STRING_D, escape_chars!(heredoc_string)]
        end
        @lineno += heredoc_string.each_line.to_a.size
      # operators of more than 1 char
      elsif operator = @s.scan(OPERATOR_REGEX)
        @token_buf << [operator, operator]
      elsif regexp = @s.scan(%r{\A/.*?[^\\]/})
        @token_buf << [:REGEXP, regexp]
      # whitespaces
      elsif @s.scan(/\A[ \t\f]+/)
      # operators and tokens of single chars, one of: ( ) , . [ ] ! + - = < > /
      else
        value = @s.getch
        if value == '|'
          @token_buf << [:NEWLINE, "\n"]
        else
          @token_buf << [value, value]
        end
        # if we encounter `funcCall().`, the next character must be treated as
        # a dictionary retrieval operation, not a string concatenation
        # operation.
        # However, if we see `funcCall().l:localVar`, we know it must be a
        # string concatenation operation.
        if value == ']' || value == ')' && (@s.peek(1) == '.' && @s.peek(3) != ':')
          parse_dict_vals!
        end
      end
    end

    # Checks if any of previous n tokens are keywords.
    # If any found, return the keyword, otherwise returns `false`.
    def prev_token_is_keyword?(n = 2)
      return false if n <= 0
      (1..n).each do |i|
        t = tokens[-i]
        if t && t[1] && KEYWORDS.include?(t[1])
          return t[1]
        end
      end
      false
    end

    private

    # we have negative lookbehind in regexp engine
    if RUBY_VERSION >= '1.9'
      # have to use string constructor, as parser would throw SyntaxError if
      # RUBY_VERSION < '1.9'. Literal regexp is `/\A"(.*?)(?<!\\)"/`
      STRING_DOUBLE_NEGATIVE_LOOKBEHIND_REGEX = Regexp.new('\A"(.*?)(?<!\\\\)"')
      def lex_string_double
        @s.scan(STRING_DOUBLE_NEGATIVE_LOOKBEHIND_REGEX) && @s[1]
      end
    # we don't have negative lookbehind in regexp engine
    else
      def lex_string_double
        str = ''
        regex = /\A"(.*?)"/
        pos = @s.pos
        while @s.scan(regex)
          match = @s[1]
          str << match
          if match[-1, 1] == '\\'
            str << '"'
            regex = /\A(.*?)"/
          else
            return str
          end
        end
        @s.pos = pos
        nil
      end
    end

    def decorate_token(token)
      token << {
        :lineno => @lineno,
        :filename => @filename
      }
    end

    def track_indent_level(identifier)
      case identifier.to_sym
      when :def, :def!, :defm, :defm!, :while, :until, :for, :try, :class
        @current_indent += 2
        @indent_pending = true
      when :if, :unless
        if !statement_modifier?
          @current_indent += 2
          @indent_pending = true
        end
      when *END_KEYWORDS.map(&:to_sym)
        @current_indent -= 2
        @dedent_pending = true
      end
    end

    # `dict.key` or `dict.key.other_key`, etc.
    def parse_dict_vals!
      if @s.scan(/\A\.([\w.]+)(?!:)/)
        vals = @s[1]
        parts = vals.split('.')
        if @in_function_declaration
          @token_buf.last[1] << ".#{vals}"
        else
          while key = parts.shift
            @token_buf << [:DICT_VAL, key]
          end
        end
      end
    end

    def check_indentation
      if @current_indent > 0
        error_msg = "Missing #{(@current_indent / 2)} END identifier(s)"
        error = Riml::SyntaxError.new(error_msg, @filename, @lineno)
        raise error
      elsif @current_indent < 0
        error_msg = "#{(@current_indent / 2).abs} too many END identifiers"
        error = Riml::SyntaxError.new(error_msg, @filename, @lineno)
        raise error
      end
    end

    def handle_interpolation(*parts)
      parts.delete_if {|p| p.empty?}.each_with_index do |part, i|
        if part[0..1] == '#{' && part[-1, 1] == '}'
          interpolation_content = part[2...-1]
          @token_buf.concat tokenize_without_moving_pos(interpolation_content)
        else
          @token_buf << [:STRING_D, escape_chars!(part)]
        end
        # string-concatenate all the parts unless this is the last part
        @token_buf << ['.', '.'] unless parts[i + 1].nil?
      end
    end

    def escape_chars!(string)
      string.gsub!(/"/, '\"')
      string.gsub!(/\n/, "\\n")
      string
    end

    def tokenize_without_moving_pos(code)
      Lexer.new(code, filename, false).tap do |l|
        l.lineno = @lineno
      end.tokenize
    end

    def statement_modifier?
      old_pos = @s.pos
      # backtrack until the beginning of the line
      @s.pos -= 1 until @s.bol?
      @s.check(/\A(.+?)(if|unless).+?$/) && !@s[1].strip.empty?
    ensure
      @s.pos = old_pos
    end

  end unless defined?(Riml::Lexer)
end
