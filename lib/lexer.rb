require File.expand_path('../constants', __FILE__)
require File.expand_path('../errors', __FILE__)

module Riml
  class Lexer
    include Riml::Constants

    SINGLE_LINE_COMMENT_REGEX = /\A\s*"(.*)$/
    OPERATOR_REGEX = /\A#{Regexp.union(['||', '&&', '===', '+=', '-=', '.='] + COMPARISON_OPERATORS)}/
    INTERPOLATION_REGEX = /\A"(.*?)(\#\{(.*?)\})(.*?)"/m
    INTERPOLATION_SPLIT_REGEX = /(\#{.*?})/m

    attr_reader :tokens, :prev_token, :lineno, :chunk, :current_indent
    # for REPL
    attr_accessor :ignore_indentation_check

    def initialize(code)
      @code = code
      @code.chomp!
      set_start_state!
    end

    def set_start_state!
      # number of characters consumed
      @i = 0
      # array of doubles and triples: [tokenname, tokenval, lineno_to_add(optional)]
      # ex: [[:NEWLINE, "\n"]] OR [[:NEWLINE, "\n", 1]]
      @token_buf = []
      @tokens = []
      @prev_token = nil
      @lineno = 1
      @current_indent = 0
      @indent_pending = false
      @dedent_pending = false
      @one_line_conditional_end_pending = false
      @splat_allowed = false
      @in_function_declaration = false
    end

    def tokenize
      set_start_state!
      while (token = next_token) != nil
        @tokens << token
      end
      @tokens
    end

    def next_token
      while @token_buf.empty? && more_code_to_tokenize?
        tokenize_chunk(get_new_chunk)
      end
      if !@token_buf.empty?
        token = @token_buf.shift
        if token.size == 3
          @lineno += token.pop
        end
        return @prev_token = token
      end
      check_indentation unless ignore_indentation_check
      nil
    end

    def tokenize_chunk(chunk)
      @chunk = chunk
      # deal with line continuations
      if cont = chunk[/\A\n*\s*\\/m]
        @i += cont.size
        @lineno += cont.each_line.to_a.size - 1
        return
      end

      # all lines that start with ':' pass right through unmodified
      if (prev_token.nil? || prev_token[0] == :NEWLINE) && (ex_literal = chunk[/\A\s*:(.*)?$/])
        @i += ex_literal.size
        @token_buf << [:EX_LITERAL, $1]
        return
      end

      if splat_var = chunk[/\Aa:\d+/]
        @i += splat_var.size
        @token_buf << [:SCOPE_MODIFIER, 'a:'] << [:IDENTIFIER, splat_var[2..-1]]
      # the 'n' scope modifier is added by riml
      elsif scope_modifier = chunk[/\A([bwtglsavn]:)\w/, 1]
        @i += 2
        @token_buf << [:SCOPE_MODIFIER, scope_modifier]
      elsif scope_modifier_literal = chunk[/\A([bwtglsavn]:)/]
        @i += scope_modifier_literal.size
        @token_buf << [:SCOPE_MODIFIER_LITERAL, scope_modifier_literal]
      elsif special_var_prefix = chunk[/\A(&(\w:)?(?!&)|\$|@)/]
        @token_buf << [:SPECIAL_VAR_PREFIX, special_var_prefix.strip]
        @expecting_identifier = true
        @i += special_var_prefix.size
      elsif function_method = chunk[/\A(function)\(/, 1]
        @token_buf << [:IDENTIFIER, function_method]
        @i += function_method.size
      elsif identifier = chunk[/\A[a-zA-Z_][\w#]*(\?|!)?/]
        # keyword identifiers
        if KEYWORDS.include?(identifier)
          if identifier.match(/\Afunction/)
            old_identifier = identifier.dup
            identifier.sub!(/function/, "def")
            @i += (old_identifier.size - identifier.size)
          elsif VIML_END_KEYWORDS.include? identifier
            old_identifier = identifier.dup
            identifier = 'end'
            @i += old_identifier.size - identifier.size
          end

          if DEFINE_KEYWORDS.include?(identifier)
            @in_function_declaration = true
          end

          # strip '?' out of token names and replace '!' with '_bang'
          token_name = identifier.sub(/\?\Z/, "").sub(/!\Z/, "_bang").upcase

          track_indent_level(chunk, identifier)
          @token_buf << [token_name.intern, identifier]

        elsif BUILTIN_COMMANDS.include? identifier
          @token_buf << [:BUILTIN_COMMAND, identifier]
        elsif RIML_COMMANDS.include? identifier
          @token_buf << [:RIML_COMMAND, identifier]
        elsif VIML_COMMANDS.include?(identifier) && (prev_token.nil? || prev_token[0] == :NEWLINE)
          @i += identifier.size
          new_chunk = get_new_chunk
          until_eol = new_chunk[/.*$/].to_s
          @token_buf << [:EX_LITERAL, identifier << until_eol]
          @i += until_eol.size
          return
        # method names and variable names
        else
          @token_buf << [:IDENTIFIER, identifier]
        end

        @i += identifier.size

        parse_dict_vals!

        if @in_function_declaration
          @in_function_declaration = false unless DEFINE_KEYWORDS.include?(identifier) && @token_buf.size == 1
        end
      elsif splat = chunk[/\A(\.{3}|\*[a-zA-Z_]\w*)/]
        raise SyntaxError, "unexpected splat, has to be enclosed in parentheses" unless @splat_allowed
        @token_buf << [:SPLAT, splat]
        @splat_allowed = false
        @i += splat.size
      # integer (octal)
      elsif octal = chunk[/\A0[0-7]+/]
        @token_buf << [:NUMBER, octal]
        @i += octal.size
      # integer (hex)
      elsif hex = chunk[/\A0[xX]\h+/]
        @token_buf << [:NUMBER, hex]
        @i += hex.size
      # integer or float (decimal)
      elsif decimal = chunk[/\A[0-9]+(\.[0-9]+)?/]
        @token_buf << [:NUMBER, decimal]
        @i += decimal.size
      elsif interpolation = chunk[INTERPOLATION_REGEX]
        # "hey there, #{name}" = "hey there, " . name
        parts = interpolation[1...-1].split(INTERPOLATION_SPLIT_REGEX)
        handle_interpolation(*parts)
        @i += interpolation.size
      elsif (single_line_comment = chunk[SINGLE_LINE_COMMENT_REGEX]) && (prev_token.nil? || prev_token[0] == :NEWLINE)
        @i += single_line_comment.size + 1 # consume next newline character
        @lineno += single_line_comment.each_line.to_a.size
      elsif inline_comment = chunk[/\A\s*"[^"]*?$/]
        @i += inline_comment.size # inline comment, don't consume newline character
        @lineno += inline_comment.each_line.to_a.size - 1
      elsif string_double = chunk[/\A"(.*?)(?<!\\)"/, 1]
        @token_buf << [:STRING_D, string_double]
        @i += string_double.size + 2
      elsif string_single = chunk[/\A'(([^']|'')*)'/, 1]
        @token_buf << [:STRING_S, string_single]
        @i += string_single.size + 2
      elsif newlines = chunk[/\A(\n+)/, 1]
        # push only 1 newline
        @token_buf << [:NEWLINE, "\n"] unless prev_token && prev_token[0] == :NEWLINE

        # pending indents/dedents
        if @one_line_conditional_end_pending
          @one_line_conditional_end_pending = false
        elsif @indent_pending
          @indent_pending = false
        elsif @dedent_pending
          @dedent_pending = false
        end

        @i += newlines.size
        @lineno += newlines.size
      elsif heredoc_pattern = chunk[%r{\A<<(.+?)\r?\n}]
        pattern = $1
        @i += heredoc_pattern.size
        new_chunk = get_new_chunk
        heredoc_string = new_chunk[%r|(.+?\r?\n)(#{Regexp.escape(pattern)})|, 1]
        @i += heredoc_string.size + pattern.size
        if ('"' + heredoc_string + '"') =~ INTERPOLATION_REGEX
          parts = heredoc_string.split(INTERPOLATION_SPLIT_REGEX)
          handle_interpolation(*parts)
        else
          @token_buf << [:STRING_D, heredoc_string]
        end
        @lineno += heredoc_string.each_line.to_a.size
      # operators of more than 1 char
      elsif operator = chunk[OPERATOR_REGEX]
        @token_buf << [operator, operator]
        @i += operator.size
      elsif regexp = chunk[%r{\A/.*?[^\\]/}]
        @token_buf << [:REGEXP, regexp]
        @i += regexp.size
      elsif whitespaces = chunk[/\A\s+/]
        @i += whitespaces.size
      # operators and tokens of single chars, one of: ( ) , . [ ] ! + - = < > /
      else
        value = chunk[0, 1]
        if value == '|'
          @token_buf << [:NEWLINE, "\n"]
        else
          @token_buf << [value, value]
        end
        @splat_allowed = true  if value == '('
        @splat_allowed = false if value == ')'
        @i += 1
        if value == ']' || value == ')' && chunk[1, 1] == '.'
          parse_dict_vals!
        end
      end
    end

    private
    def track_indent_level(chunk, identifier)
      case identifier.to_sym
      when :def, :def!, :defm, :defm!, :while, :until, :for, :try, :class
        @current_indent += 2
        @indent_pending = true
      when :if, :unless
        if one_line_conditional?(chunk)
          @one_line_conditional_end_pending = true
        elsif !statement_modifier?
          @current_indent += 2
          @indent_pending = true
        end
      when :end
        unless @one_line_conditional_end_pending
          @current_indent -= 2
          @dedent_pending = true
        end
      end
    end

    def parse_dict_vals!
      # dict.key OR dict.key.other_key
      new_chunk = get_new_chunk
      if vals = new_chunk[/\A\.([\w.]+)/, 1]
        parts = vals.split('.')
        @i += vals.size + 1
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
      raise SyntaxError, "Missing #{(@current_indent / 2)} END identifier(s), " if @current_indent > 0
      raise SyntaxError, "#{(@current_indent / 2).abs} too many END identifiers" if @current_indent < 0
    end

    def one_line_conditional?(chunk)
      chunk[/^(if|unless).+?(else)?.+?end$/]
    end

    def handle_interpolation(*parts)
      parts.delete_if {|p| p.empty?}.each_with_index do |part, i|
        if part[0..1] == '#{' && part[-1] == '}'
          @token_buf.concat tokenize_without_moving_pos(part[2...-1])
        else
          @token_buf << [:STRING_D, part]
        end
        # string-concatenate all the parts unless this is the last part
        @token_buf << ['.', '.'] unless parts[i + 1].nil?
      end
    end

    def tokenize_without_moving_pos(code)
      Lexer.new(code).tokenize
    end

    def statement_modifier?
      old_i = @i
      # backtrack until the beginning of the line
      @i -= 1 while @code[@i-1] =~ /[^\n\r]/ && !@code[@i-1].empty?
      new_chunk = get_new_chunk
      new_chunk[/^(.+?)(if|unless).+$/] && !$1.strip.empty?
    ensure
      @i = old_i
    end

    def get_new_chunk
      @code[@i..-1]
    end

    def more_code_to_tokenize?
      @i < @code.size
    end
  end
end
