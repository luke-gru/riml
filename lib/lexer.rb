module Riml
  class Lexer
    KEYWORDS = %w(def end if then else elsif true false nil return)

    def tokenize(code)
      code.chomp!
      i = 0
      tokens = []
      current_indent = 0
      indent_pending = false
      dedent_pending = false
      one_line_if_expression_END_pending = false

      while i < code.size
        chunk = code[i..-1]

        if scope_modifier = chunk[/\A(s|b):/]
          tokens << [:SCOPE_MODIFIER, scope_modifier]
          i += 2
        elsif identifier = chunk[/\A([a-z]\w*)/]
          # keyword identifiers
          if KEYWORDS.include?(identifier)
            tokens << [identifier.upcase.intern, identifier]
            case identifier
            when "def"
              current_indent += 2
              indent_pending = true
            when "if"
              if one_line_if_statement?(chunk)
                one_line_if_expression_END_pending = true
              else
                current_indent += 2
                indent_pending = true
              end
            when "end"
              unless one_line_if_expression_END_pending
                current_indent -= 2
                dedent_pending = true
              end
            else
            end
          # method and variable names
          else
            tokens << [:IDENTIFIER, identifier ]
          end
          i += identifier.size
        elsif constant = chunk[/\A([A-Z]\w*)/]
          tokens << [:CONSTANT, constant]
          i += constant.size
        elsif number = chunk[/\A([0-9]+)/]
          tokens << [:NUMBER, number.to_i]
          i += number.size
        elsif string = chunk[/\A"(.*?)"/, 1]
          tokens << [:STRING, string]
          i += string.size + 2
        elsif newlines = chunk[/\A(\n+)/, 1]
          # just push 1 newline
          tokens << [:NEWLINE, "\n"]

          # pending indents/dedents
          if indent_pending
            tokens << [:INDENT, current_indent]
            indent_pending = false
          elsif dedent_pending
            tokens << [:DEDENT, current_indent]
            dedent_pending = false
          end

          i += newlines.size
        # operators of more than 1 char
        elsif operator = chunk[%r{\A(\|\||&&|==|!=|<=|>=)}, 1]
          tokens << [operator, operator]
        elsif whitespaces = chunk[/\A +/]
          i += whitespaces.size
        # operators and tokens of single chars ( ) , . [ ] ! + - = < >
        else
          value = chunk[0, 1]
          tokens << [value, value]
          i += 1
        end
      end
      raise "Missing #{current_indent / 2} END identifier(s), " unless current_indent.zero?

      tokens
    end

    private

    def one_line_if_statement?(chunk)
      chunk[/^if.*?(else)?.*?end$/]
    end

  end
end
