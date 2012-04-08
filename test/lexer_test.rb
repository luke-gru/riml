require_relative 'test_helper'

class BasicLexerTest < Riml::TestCase

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
    @tokens = lex(code)
    expected =
    [
      [:IF, "if"], [:NUMBER, 1], [:NEWLINE, "\n"],
        [:INDENT, 2], [:IDENTIFIER, "print"], [:STRING, '...'], [:NEWLINE, "\n"],
        [:IF, "if"], [:FALSE, 'false'], [:NEWLINE, "\n"],
          [:INDENT, 4], [:IDENTIFIER, "do_something"], [:NEWLINE, "\n"],
        [:END, 'end'], [:NEWLINE, "\n"], [:DEDENT, 2],
      [:END, 'end'], [:NEWLINE, "\n"], [:DEDENT, 0],
      [:IDENTIFIER, 'print'], [:STRING, 'omg'], [';', ';']
    ]
    assert_equal expected, @tokens
  end

  test "lexing a ruby-like if this then that end expression" do
    code = <<-Riml
    if b then a = 2 end
    Riml
    @tokens = lex(code)
    expected =
      [[:IF, "if"],
      [:IDENTIFIER, "b"],
      [:THEN, "then"],
      [:IDENTIFIER, "a"],
      ["=", "="],
      [:NUMBER, 2],
      [:END, "end"]]
    assert_equal expected, @tokens
  end
end
