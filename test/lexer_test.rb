require File.expand_path('../test_helper', __FILE__)

class BasicLexerTest < Riml::TestCase

  test "basic lexing" do
    riml = <<-Riml
    if 1
      print "..."
      if false
        do_something
      end
    end
    print "omg";
    Riml
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
    assert_equal expected, lex(riml)
  end

  test "lexing a ruby-like if this then that end expression" do
    riml = <<-Riml
    if b then a = 2 end\n
    Riml
    expected =
      [[:IF, "if"],
      [:IDENTIFIER, "b"],
      [:THEN, "then"],
      [:IDENTIFIER, "a"],
      ["=", "="],
      [:NUMBER, 2],
      [:END, "end"],
      [:NEWLINE, "\n"]
    ]
    assert_equal expected, lex(riml)
  end


  test "lexing an unless expression" do
    riml = <<Riml
unless b:salutation
  echo "hi";
end
Riml

    expected = [
      [:UNLESS, "unless"],
      [:SCOPE_MODIFIER, "b:"],
      [:IDENTIFIER, "salutation"],
      [:NEWLINE, "\n"],
      [:INDENT, 2],
      [:IDENTIFIER, "echo"],
      [:STRING, "hi"],
      [";", ";"],
      [:NEWLINE, "\n"],
      [:END, "end"]
     ]

    assert_equal expected, lex(riml)
  end
end
