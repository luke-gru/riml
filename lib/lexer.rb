require File.expand_path('../constants', __FILE__)
require File.expand_path('../errors', __FILE__)

module Riml
  class Lexer
    include Riml::Constants

    SINGLE_LINE_COMMENT_REGEX = /\A\s*"(.*)$/
    OPERATOR_REGEX = /\A#{Regexp.union(['||', '&&', '===', '+=', '-='] + COMPARISON_OPERATORS)}/

    attr_reader :tokens, :prev_token, :lineno, :chunk

    def initialize(code)
      @code = code
      @code.chomp!
      @i = 0 # number of characters consumed
      @token_buf = []
      @tokens = []
      @prev_token = nil
      @lineno = 1
      @current_indent = 0
      @indent_pending = false
      @dedent_pending = false
      @one_line_conditional_END_pending = false
      @splat_allowed = false
    end

    def tokenize
      while more_code_to_tokenize?
        new_token = next_token
        @tokens << new_token unless new_token.nil?
      end
      @tokens
    end

    def next_token
      if @token_buf.any?
        return @prev_token = @token_buf.shift
      end
      while @token_buf.empty? && more_code_to_tokenize?
        tokenize_chunk(get_new_chunk)
      end
      if @token_buf.any?
        return @prev_token = @token_buf.shift
      end
      check_indentation
      nil
    end

    def tokenize_chunk(chunk)
      @chunk = chunk
      # deal with line continuations
      if cont = chunk[/\A(\n*)\s*\\/]
        @i += cont.size
        @lineno += $1.size
        return
      end

      # all lines that start with ':' pass right through unmodified
      if (prev_token.nil? || prev_token[0] == :NEWLINE) && (ex_literal = chunk[/\A\s*:(.*)?$/])
        @i += ex_literal.size
        @token_buf << [:EX_LITERAL, $1]
        return
      end

      if splatted_arg = chunk[/\Aa:\d+/]
        @i += splatted_arg.size
        @token_buf << [:SCOPE_MODIFIER, 'a:'] << [:IDENTIFIER, splatted_arg[2..-1]]
      # the 'n' scope modifier is added by riml
      elsif scope_modifier = chunk[/\A([bwtglsavn]:)[\w_]/]
        @i += 2
        @token_buf << [:SCOPE_MODIFIER, $1]
      elsif scope_modifier_literal = chunk[/\A([bwtglsavn]:)/]
        @i += 2
        @token_buf << [:SCOPE_MODIFIER_LITERAL, $1]
      elsif special_var_prefix = chunk[/\A[&$@]/]
        @token_buf << [:SPECIAL_VAR_PREFIX, special_var_prefix]
        @expecting_identifier = true
        @i += 1
      elsif function_reference = chunk[/\A(function)\(/]
        @token_buf << [:IDENTIFIER, $1]
        @i += $1.size
      elsif identifier = chunk[/\A[a-zA-Z_][\w#]*\??/]
        # keyword identifiers
        if KEYWORDS.include?(identifier)
          if identifier == 'function'
            old_identifier = identifier.dup
            identifier = 'def'
            @i += (old_identifier.size - 3)
          elsif identifier == 'finally'
            identifier = 'ensure'
            @i += 1 # diff b/t the two string lengths
          elsif VIML_END_KEYWORDS.include? identifier
            old_identifier = identifier.dup
            identifier = 'end'
            @i += old_identifier.size - identifier.size
          end

          if DEFINE_KEYWORDS.include?(identifier)
            @in_function_declaration = true
          end

          # strip out '?' for token names
          token_name = identifier[-1] == ?? ? identifier[0..-2] : identifier

          track_indent_level(chunk, identifier)
          @token_buf << [token_name.upcase.intern, identifier]

        elsif BUILTIN_COMMANDS.include? identifier
          @token_buf << [:BUILTIN_COMMAND, identifier]
        # method names and variable names
        else
          @token_buf << [:IDENTIFIER, identifier]
        end

        @i += identifier.size

        # dict.key OR dict.key.other_key
        new_chunk = get_new_chunk
        if new_chunk[/\A\.([\w.]+)/]
          parts = $1.split('.')
          @i += $1.size + 1
          if @in_function_declaration
            @token_buf.last[1] << ".#{$1}"
          else
            while key = parts.shift
              @token_buf << [:DICT_VAL, key]
            end
          end
        end

        @in_function_declaration = false unless @token_buf.last[0] == :DEF
      elsif splat = chunk[/\A(\.{3}|\*[a-zA-Z_]\w*)/]
        raise SyntaxError, "unexpected splat, has to be enclosed in parentheses" unless @splat_allowed
        @token_buf << [:SPLAT, splat]
        @splat_allowed = false
        @i += splat.size
      # integer (octal)
      elsif octal = chunk[/\A0[0-7]+/]
        @token_buf << [:NUMBER, octal.to_s]
        @i += octal.size
      # integer (hex)
      elsif hex = chunk[/\A0[xX]\h+/]
        @token_buf << [:NUMBER, hex.to_s]
        @i += hex.size
      # integer or float (decimal)
      elsif decimal = chunk[/\A[0-9]+(\.[0-9]+)?/]
        @token_buf << [:NUMBER, decimal.to_s]
        @i += decimal.size
      elsif interpolation = chunk[/\A"(.*?)(\#\{(.*?)\})(.*?)"/]
        # "#{hey} guys" = "hey" . " guys"
        unless $1.empty?
          @token_buf << [:STRING_D, $1]
          @token_buf << ['.', '.']
        end
        @token_buf << [:IDENTIFIER, $3]
        unless $4.empty?
          @token_buf << ['.', '.']
          @token_buf << [ :STRING_D, " #{$4[1..-1]}" ]
        end
        @i += interpolation.size
      elsif single_line_comment = chunk[SINGLE_LINE_COMMENT_REGEX] && (prev_token.nil? || prev_token[0] == :NEWLINE)
        comment = chunk[SINGLE_LINE_COMMENT_REGEX]
        @i += comment.size + 1 # consume next newline character
        @lineno += 1
      elsif inline_comment = chunk[/\A\s*"[^"]*?$/]
        @i += inline_comment.size # inline comment, don't consume newline character
      elsif string_double = chunk[/\A"(.*?)"/, 1]
        @token_buf << [:STRING_D, string_double]
        @i += string_double.size + 2
      elsif string_single = chunk[/\A'(([^']|'')*)'/, 1]
        @token_buf << [:STRING_S, string_single]
        @i += string_single.size + 2
      elsif newlines = chunk[/\A(\n+)/, 1]
        # push only 1 newline
        @token_buf << [:NEWLINE, "\n"]

        @inline_comment_allowed = false

        # pending indents/dedents
        if @one_line_conditional_END_pending
          @one_line_conditional_END_pending = false
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
        @token_buf << [:HEREDOC, pattern]
        new_chunk = get_new_chunk
        heredoc_string = new_chunk[%r|(.+?\r?\n)(#{Regexp.escape(pattern)})|]
        @i += heredoc_string.size + $2.size
        @token_buf << [:STRING_D, $1]
        @lineno += (1 + heredoc_string.each_line.to_a.size)
      # operators of more than 1 char
      elsif operator = chunk[OPERATOR_REGEX]
        @token_buf << [operator, operator]
        @i += operator.size
      # FIXME: this doesn't work well enough
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
      end
    end

    private
    def track_indent_level(chunk, identifier)
      case identifier.to_sym
      when :def, :defm, :while, :until, :for, :try, :class
        @current_indent += 2
        @indent_pending = true
      when :if, :unless
        if one_line_conditional?(chunk)
          @one_line_conditional_END_pending = true
        elsif !statement_modifier?(chunk)
          @current_indent += 2
          @indent_pending = true
        end
      when :end
        unless @one_line_conditional_END_pending
          @current_indent -= 2
          @dedent_pending = true
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

    def statement_modifier?(chunk)
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
