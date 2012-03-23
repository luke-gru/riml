require_relative 'test_helper'
require 'lexer'

class BasicLexerTest < ActiveSupport::TestCase
  def setup
    @lexer = Riml::Lexer.new
  end

  def lex(code)
    @tokens = @lexer.tokenize(code)
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
        [:IDENTIFIER, "print"], [:STRING, '...'], [:NEWLINE, "\n"],
        [:IF, "if"], [:FALSE, 'false'], [:NEWLINE, "\n"],
          [:IDENTIFIER, "do_something"], [:NEWLINE, "\n"],
        [:END, 'end'], [:NEWLINE, "\n"],
      [:END, 'end'], [:NEWLINE, "\n"],
      [:IDENTIFIER, 'print'], [:STRING, 'omg'], [';', ';']
    ]
    assert_equal tokens, @tokens
  end
end
