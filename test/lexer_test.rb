require File.expand_path('../test_helper', __FILE__)

module Riml
class BasicLexerTest < Riml::TestCase

  test "if statement" do
    riml = <<-Riml
    if 1
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

  test "ignore single_line comments" do
    riml = <<Riml
" this is a comment
" this is a comment with "a nested" double-quote
if do_something()
  do_something_1()
else
  do_something_2()
end
Riml

    expected = [
      [:IF, "if"], [:IDENTIFIER, "do_something"], ["(", "("], [")", ")"], [:NEWLINE, "\n"],
        [:IDENTIFIER, "do_something_1"], ["(", "("], [")", ")"], [:NEWLINE, "\n"],
      [:ELSE, "else"], [:NEWLINE, "\n"],
        [:IDENTIFIER, "do_something_2"], ["(", "("], [")", ")"], [:NEWLINE, "\n"],
      [:END, "end"]
    ]
    assert_equal expected, lex(riml)
  end

  test "ignore inline comment after function name definition" do
    riml = <<Riml
function! smartinput#clear_rules()  "{{{2
  let s:available_nrules = []
endfunction
Riml

    expected = [
      [:DEF_BANG, "def!"], [:IDENTIFIER, "smartinput#clear_rules"], ["(", "("], [")", ")"], [:NEWLINE, "\n"],
        [:LET, "let"], [:SCOPE_MODIFIER, "s:"], [:IDENTIFIER, "available_nrules"], ["=", "="], ["[", "["], ["]", "]"], [:NEWLINE, "\n"],
      [:END, "endfunction"]
    ]
    assert_equal expected, lex(riml)
  end

  test "allow double single-quotes in single-quote in literal string" do
    riml = %{echo ''''''}
    expected = [
      [:BUILTIN_COMMAND, "echo" ],
      [:STRING_S, "''''"]
    ]
    assert_equal expected, lex(riml)
  end

  test "scope modifier literal" do
    riml = <<Riml
if s:var
  return s:
else
  return g:
end
Riml

    expected = [
      [:IF, "if"], [:SCOPE_MODIFIER, "s:"], [:IDENTIFIER, "var"], [:NEWLINE, "\n"],
        [:RETURN, "return"], [:SCOPE_MODIFIER_LITERAL, "s:"], [:NEWLINE, "\n"],
      [:ELSE, "else"], [:NEWLINE, "\n"],
        [:RETURN, "return"], [:SCOPE_MODIFIER_LITERAL, "g:"], [:NEWLINE, "\n"],
      [:END, "end"]
    ]
    assert_equal expected, lex(riml)
  end

  test "ex-literals (line starts with ':') pass right through" do
    riml = <<Riml
if s:var
  :au something
else
  :au somethingElse
end
Riml
    expected = [
      [:IF, "if"], [:SCOPE_MODIFIER, "s:"], [:IDENTIFIER, "var"], [:NEWLINE, "\n"],
        [:EX_LITERAL, "au something"], [:NEWLINE, "\n"],
      [:ELSE, "else"], [:NEWLINE, "\n"],
        [:EX_LITERAL, "au somethingElse"], [:NEWLINE, "\n"],
      [:END, "end"]
    ]
    assert_equal expected, lex(riml)
  end

  test "BUILTIN_FUNCTION 'function' doesn't get lexed as FUNCTION keyword" do
    riml = <<Riml
let M = function('smartinput#map_to_trigger')
Riml
    expected = [
      [:LET, "let"], [:IDENTIFIER, "M"], ["=", "="], [:IDENTIFIER, "function"], ["(", "("],
      [:STRING_S, "smartinput#map_to_trigger"], [")", ")"]
    ]
    assert_equal expected, lex(riml)
  end

  test "line continuations" do

    riml = <<Riml
echo lnum == 1
\\     ? "top"
\\     : lnum == 1000
\\             ? "last"
\\             : lnum
Riml
    expected = [
      [:BUILTIN_COMMAND, "echo"], [:IDENTIFIER, "lnum"], ["==", "=="], [:NUMBER, "1"],
      ["?", "?"], [:STRING_D, "top"],
      [":", ":"], [:IDENTIFIER, "lnum"], ["==", "=="], [:NUMBER, "1000"],
      ["?", "?"], [:STRING_D, "last"],
      [":", ":"], [:IDENTIFIER, "lnum"]
    ]
    assert_equal expected, lex(riml)
  end

  # https://github.com/luke-gru/riml/issues/11
  test "newlines can be either <NL>, <CR> or <CR><NL>" do
    newline_map = {"<NL>" => "\n", "<CR>" => "\r", "<CR><NL>" => "\r\n"}

    newline_map.each do |name, nl|
      riml = "echo 'hello'#{nl}#{nl}  ;"
      expected = [
        [:BUILTIN_COMMAND, "echo"], [:STRING_S, 'hello'], [:NEWLINE, "\n"],
        [';', ';']
      ]
      assert_equal expected, lex(riml), "expected newline '#{name}' to act as a :NEWLINE"
    end
  end
end
end
