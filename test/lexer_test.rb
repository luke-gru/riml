require_relative 'test_helper'
require 'lexer'

class BasicLexerTest < Riml::TestCase
  def setup
    @lexer = Riml::Lexer.new
  end

  test "basic lexing" do
    code = <<-Riml
    if 1
      print "..."
      if false
        do_something
      end
    end
    print "omg";
    Riml
    lex(code)
    tokens =
    [
      [:IF, "if"], [:NUMBER, 1], [:NEWLINE, "\n"],
        [:INDENT, 2], [:IDENTIFIER, "print"], [:STRING, '...'], [:NEWLINE, "\n"],
        [:IF, "if"], [:FALSE, 'false'], [:NEWLINE, "\n"],
          [:INDENT, 4], [:IDENTIFIER, "do_something"], [:NEWLINE, "\n"],
        [:END, 'end'], [:NEWLINE, "\n"], [:DEDENT, 2],
      [:END, 'end'], [:NEWLINE, "\n"], [:DEDENT, 0],
      [:IDENTIFIER, 'print'], [:STRING, 'omg'], [';', ';']
    ]
    assert_equal tokens, @tokens
  end

  test "" do
  end
end
