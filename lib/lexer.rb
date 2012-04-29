module Riml
  class Lexer
    RIML_KEYWORDS = %w(def function end if then else elsif unless while for in
                       true false nil command command? return finish break
                       continue)
    VIML_END_KEYWORDS = %w(endif endfunction endwhile endfor)
    KEYWORDS = RIML_KEYWORDS + VIML_END_KEYWORDS

    def tokenize(code)
      code.chomp!
      @i = 0 # number of characters consumed
      @tokens = []
      @current_indent = 0
      @indent_pending = false
      @dedent_pending = false
      @expecting_identifier = false
      @one_line_conditional_END_pending = false

      while @i < code.size
        chunk = code[@i..-1]

        if scope_modifier = chunk[/\A(s|b|w|g|v|a):/]
          raise SyntaxError, "expected identifier after scope modifier" if @expecting_identifier
          @tokens << [:SCOPE_MODIFIER, scope_modifier]
          @expecting_identifier = true
          @i += 2
        elsif identifier = chunk[/\A[a-zA-Z_]\w*\??/]

          # keyword identifiers
          if KEYWORDS.include?(identifier)
            if identifier == 'function'
              identifier = 'def'
              @i += 'function'.size - 'def'.size
            elsif VIML_END_KEYWORDS.include? identifier
              old_identifier = identifier.dup
              identifier = 'end'
              @i += old_identifier.size - identifier.size
            end
            # strip out '?' for token names
            token_name = identifier[-1] == ?? ? identifier[0..-2] : identifier
            @tokens << [token_name.upcase.intern, identifier]

            track_indent_level(chunk, identifier)
          # method names and variable names
          else
            @tokens << [:IDENTIFIER, identifier]
          end

          @expecting_identifier = false
          @i += identifier.size

        elsif @expecting_identifier
          raise SyntaxError, "expected identifier after scope modifier"
        elsif constant = chunk[/\A[A-Z]\w*/]
          @tokens << [:CONSTANT, constant]
          @i += constant.size
        elsif number = chunk[/\A[0-9]+/]
          @tokens << [:NUMBER, number.to_i]
          @i += number.size
        elsif interpolation = chunk[/\A"(.*?)(\#{(.*?)})(.*?)"/]
          # "#{hey} guys" = hey . " guys"
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
        elsif string = chunk[/\A("|')(.*?)(\1)/, 2]
          type = ($1 == '"' ? :D : :S)
          @tokens << [:"STRING_#{type}", string]
          @i += string.size + 2
        elsif newlines = chunk[/\A(\n+)/, 1]
          # just push 1 newline
          @tokens << [:NEWLINE, "\n"]

          # pending indents/dedents
          if @one_line_conditional_END_pending
            @one_line_conditional_END_pending = false
          elsif @indent_pending
            @tokens << [:INDENT, @current_indent]
            @indent_pending = false
          elsif @dedent_pending
            @tokens << [:DEDENT, @current_indent]
            @dedent_pending = false
          end

          @i += newlines.size
        # operators of more than 1 char
        elsif operator = chunk[%r{\A(\|\||&&|==|!=|<=|>=|\+=|-=)}, 1]
          @tokens << [operator, operator]
          @i += operator.size
        elsif whitespaces = chunk[/\A +/]
          @i += whitespaces.size
        elsif single_line_comment = chunk[/\A\s*#.*$/]
          @i += single_line_comment.size
        # operators and tokens of single chars, one of: ( ) , . [ ] ! + - = < >
        else
          value = chunk[0, 1]
          @tokens << [value, value]
          @i += 1
        end
      end
      raise SyntaxError, "Missing #{(@current_indent / 2)} END identifier(s), " if @current_indent > 0
      raise SyntaxError, "#{(@current_indent / 2).abs} too many END identifiers" if @current_indent < 0

      @tokens
    end

    private
    def track_indent_level(chunk, identifier)
      case identifier
      when "def", "while", "for"
        @current_indent += 2
        @indent_pending = true
      when "if", "unless"
        if one_line_conditional?(chunk)
          @one_line_conditional_END_pending = true
        else
          @current_indent += 2
          @indent_pending = true
        end
      when "end"
        unless @one_line_conditional_END_pending
          @current_indent -= 2
          @dedent_pending = true
        end
      end
    end

    def one_line_conditional?(chunk)
      res = chunk[/^(if|unless).*?(else)?.*?end$/]
    end
  end
end
