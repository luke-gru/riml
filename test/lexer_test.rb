require File.expand_path('../test_helper', __FILE__)

class BasicLexerTest < Riml::TestCase

  test "if statement" do
    riml = <<-Riml
    if 1 #### comment
      print '...'
      if false
        do_something
      end
    end
    print "omg";
    Riml
    expected =
    [
      [:IF, "if"], [:NUMBER, "1"], [:NEWLINE, "\n"],
        [:IDENTIFIER, "print"], [:STRING_S, '...'], [:NEWLINE, "\n"],
        [:IF, "if"], [:FALSE, 'false'], [:NEWLINE, "\n"],
        [:IDENTIFIER, "do_something"], [:NEWLINE, "\n"],
        [:END, 'end'], [:NEWLINE, "\n"],
      [:END, 'end'], [:NEWLINE, "\n"],
      [:IDENTIFIER, 'print'], [:STRING_D, 'omg'], [';', ';']
    ]
    assert_equal expected, lex(riml)
  end

  test "ruby-like if this then that end expression" do
    riml = <<-Riml
    if b then a = 2 end\n
    Riml
    expected =
      [[:IF, "if"],
      [:IDENTIFIER, "b"],
      [:THEN, "then"],
      [:IDENTIFIER, "a"],
      ["=", "="],
      [:NUMBER, "2"],
      [:END, "end"],
      [:NEWLINE, "\n"]
    ]
    assert_equal expected, lex(riml)
  end


  test "unless expression" do
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
      [:BUILTIN_COMMAND, "echo"],
      [:STRING_D, "hi"],
      [";", ";"],
      [:NEWLINE, "\n"],
      [:END, "end"]
     ]

    assert_equal expected, lex(riml)
  end

  test "method definition on dictionary" do
    riml = <<Riml
myDict = {'msg': 'hey'}
def myDict.echoMsg
  echo self.msg
end
Riml

    expected = [
      [:IDENTIFIER, "myDict"], ["=", "="],
        ["{", "{"],
          [:STRING_S, "msg"],
      [":", ":"],
          [:STRING_S, "hey"],
        ["}", "}"], [:NEWLINE, "\n"],
      [:DEF, "def"], [:IDENTIFIER, "myDict.echoMsg"], [:NEWLINE, "\n"],
        [:BUILTIN_COMMAND, "echo"],
          [:IDENTIFIER, "self"], [:DICT_VAL, "msg"], [:NEWLINE, "\n"],
      [:END, "end"]
    ]
    assert_equal expected, lex(riml)
  end
end
