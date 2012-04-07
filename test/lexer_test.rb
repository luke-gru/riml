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

  test "lexing a ruby-like if this then that else that2 end expression" do
    code = <<-Riml
    if b = 1 then a = 2 else a = 1 end
    Riml
    lex(code)
    tokens =
      [[:IF, "if"],
      [:IDENTIFIER, "b"],
      ["=", "="],
      [:NUMBER, 1],
      [:THEN, "then"],
      [:IDENTIFIER, "a"],
      ["=", "="],
      [:NUMBER, 2],
      [:ELSE, "else"],
      [:IDENTIFIER, "a"],
      ["=", "="],
      [:NUMBER, 1],
      [:END, "end"]]
    assert_equal tokens, @tokens
  end
end
