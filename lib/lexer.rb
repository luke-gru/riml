require File.expand_path('../constants', __FILE__)

module Riml
  class Lexer
    include Riml::Constants
    class MissingChunk < ArgumentError; end

    COMMENT_REGEX = /\A\s*".*$/

    def tokenize(code)
      @code = code
      @code.chomp!
      @i = 0 # number of characters consumed
      @tokens = []
      @current_indent = 0
      @indent_pending = false
      @dedent_pending = false
      @one_line_conditional_END_pending = false
      @inline_comment_allowed = false
      @splat_allowed = false
      @line = 0

      while more_code_to_tokenize?
        begin
          tokenize_chunk(get_new_chunk)
        rescue MissingChunk
          break
        end
      end
      raise SyntaxError, "Missing #{(@current_indent / 2)} END identifier(s), " if @current_indent > 0
      raise SyntaxError, "#{(@current_indent / 2).abs} too many END identifiers" if @current_indent < 0
      @tokens
    end

    def tokenize_chunk(chunk)
      raise MissingChunk, "chunk is #{chunk.inspect}" unless chunk

      # deal with line continuations
      if cont = chunk[/\A\\/]
        @i += 1
        @tokens.pop until @tokens.last[0] != :NEWLINE
        return
      end

      # the 'n' scope modifier is added by riml
      if scope_modifier = chunk[/\A[bwtglsavn]:/]
        @i += 2
        if lookahead_token[0] != :IDENTIFIER
          @tokens << [:SCOPE_MODIFIER_LITERAL, scope_modifier]
        else
          @tokens << [:SCOPE_MODIFIER, scope_modifier]
        end
      elsif special_var_prefix = chunk[/\A[&$@]/]
        @tokens << [:SPECIAL_VAR_PREFIX, special_var_prefix]
        @expecting_identifier = true
        @i += 1
      elsif identifier = chunk[/\A[a-zA-Z_][\w#]*\??/]
        # keyword identifiers
        if KEYWORDS.include?(identifier)
          if identifier == 'function'
            identifier = 'def'
            @i += 5 # diff b/t the two string lengths
            @inline_comment_allowed = true
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
          @tokens << [token_name.upcase.intern, identifier]

        elsif BUILTIN_COMMANDS.include? identifier
          @tokens << [:BUILTIN_COMMAND, identifier]
        # method names and variable names
        else
          @tokens << [:IDENTIFIER, identifier]
        end

        @i += identifier.size

        # dict.key OR dict.key.other_key
        new_chunk = get_new_chunk
        if new_chunk[/\A\.([\w.]+)/]
          parts = $1.split('.')
          @i += $1.size + 1
          if @in_function_declaration
            @tokens.last[1] << ".#{$1}"
          else
            while key = parts.shift
              @tokens << [:DICT_VAL, key]
            end
          end
        end

        @in_function_declaration = false unless @tokens.last[0] == :DEF
      elsif splat = chunk[/\A(\.{3}|\*[a-zA-Z_]\w*)/]
        raise SyntaxError, "unexpected splat, has to be enclosed in parentheses" unless @splat_allowed
        @tokens << [:SPLAT, splat]
        @splat_allowed = false
        @i += splat.size
      # integer (octal)
      elsif octal = chunk[/\A0[0-7]+/]
        @tokens << [:NUMBER, octal.to_s]
        @i += octal.size
      # integer (hex)
      elsif hex = chunk[/\A0[xX]\h+/]
        @tokens << [:NUMBER, hex.to_s]
        @i += hex.size
      # integer or float (decimal)
      elsif decimal = chunk[/\A[0-9]+(\.[0-9]+)?/]
        @tokens << [:NUMBER, decimal.to_s]
        @i += decimal.size
      elsif interpolation = chunk[/\A"(.*?)(\#\{(.*?)\})(.*?)"/]
        # "#{hey} guys" = "hey" . " guys"
        unless $1.empty?
          @tokens << [:STRING_D, $1]
          @tokens << ['.', '.']
        end
        @tokens << [:IDENTIFIER, $3]
        unless $4.empty?
          @tokens << ['.', '.']
          @tokens << [ :STRING_D, " #{$4[1..-1]}" ]
        end
        @i += interpolation.size
      elsif inline_comment = chunk[COMMENT_REGEX] && @inline_comment_allowed
        comment = chunk[COMMENT_REGEX]
        @i += comment.size # inline comment, don't consume newline character
      elsif single_line_comment = chunk[COMMENT_REGEX] && (@tokens.last.nil? || @tokens.last[0] == :NEWLINE)
        comment = chunk[COMMENT_REGEX]
        @i += comment.size + 1 # consume next newline character
      elsif string = chunk[/\A("|')(.*?)(\1)/, 2]
        type = ($1 == '"' ? :D : :S)
        @tokens << [:"STRING_#{type}", string]
        @i += string.size + 2
      elsif newlines = chunk[/\A(\n+)/, 1]
        # push only 1 newline
        @tokens << [:NEWLINE, "\n"]
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
      # operators of more than 1 char
      elsif operator = chunk[%r{\A(\|\||&&|===|==|!=|<=|>=|\+=|-=|=~)}, 1]
        @tokens << [operator, operator]
        @i += operator.size
      # FIXME: this doesn't work well enough
      elsif regexp = chunk[%r{\A/.*?[^\\]/}]
        @tokens << [:REGEXP, regexp]
        @i += regexp.size
      elsif whitespaces = chunk[/\A\s+/]
        @i += whitespaces.size
      elsif heredoc_pattern = chunk[%r{\A<<(.+?)\r?\n}]
        pattern = $1
        @i += heredoc_pattern.size
        @tokens << [:HEREDOC, pattern]
        new_chunk = get_new_chunk
        heredoc_string = new_chunk[%r|(.+?\r?\n)(#{Regexp.escape(pattern)})|]
        @i += heredoc_string.size + $2.size
        @tokens << [:STRING_D, $1]
      # operators and tokens of single chars, one of: ( ) , . [ ] ! + - = < > /
      else
        value = chunk[0, 1]
        if value == '|'
          @tokens << [:NEWLINE, "\n"]
        else
          @tokens << [value, value]
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

    def lookahead_token
      return [] unless more_code_to_tokenize?
      old_i, old_tokens = @i, @tokens
      @tokens = []
      until @tokens.size == 1
        tokenize_chunk(get_new_chunk)
      end
      @tokens.first
    ensure
      @i, @tokens = old_i, old_tokens
    end

    def get_new_chunk
      @code[@i..-1]
    end

    def more_code_to_tokenize?
      @i < @code.size
    end
  end
end
