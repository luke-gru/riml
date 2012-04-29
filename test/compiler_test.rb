require File.expand_path('../test_helper', __FILE__)

class BasicCompilerTest < Riml::TestCase
  Compiler = Riml::Compiler

  def setup
    Compiler.global_variables.clear
  end

  test "basic function compiles" do
    riml = <<Riml
def a_method(a, b)
  true
end
Riml

    nodes = Nodes.new([
      DefNode.new(nil, "a_method", ['a', 'b'], nil,
        Nodes.new([TrueNode.new]), 2
      )
    ])

    expected = <<Viml
function s:A_method(a, b)
  return 1
endfunction
Viml

    assert_equal expected, compile(nodes)
    assert_equal expected, compile(riml)
  end

  test "branching function compiles and returns on all branches" do
    riml = <<Riml
function b:another_method(a, b)
  if hello()
    false
  else
    true
  end
end
Riml

    nodes = Nodes.new([
      DefNode.new('b:', "another_method", ['a', 'b'], nil, Nodes.new(
        [IfNode.new(CallNode.new(nil, "hello", []), Nodes.new([FalseNode.new, ElseNode.new(Nodes.new([TrueNode.new]))]))]
      ),2)
    ])

    expected = <<Viml
function b:Another_method(a, b)
  if (hello())
    return 0
  else
    return 1
  endif
endfunction
Viml

    assert_equal expected, compile(nodes)
    assert_equal expected, compile(riml)
  end

  test "ruby-like if this then that end expression" do
    riml = "if b() then a = 2 end"
    nodes = Nodes.new([
      IfNode.new(
        CallNode.new(nil, 'b', []),
        Nodes.new(
          [SetVariableNode.new(nil, 'a', NumberNode.new(2))]
        )
      )
    ])

  expected = <<Viml
if (b())
  let s:a = 2
endif
Viml

    assert_equal expected, compile(nodes)
    assert_equal expected, compile(riml)
  end

  test "setting variable to nil frees its memory" do
    riml = "b:a = nil"
    expected = "unlet! b:a\n"

    assert_equal expected, compile(riml)
    assert_equal 1, Compiler.global_variables.count
  end

  test "unless expression" do
    riml = <<Riml
unless shy()
  echo('hi');
end
Riml

    expected = <<Viml
if (!shy())
  echo('hi')
endif
Viml

    assert_equal expected, compile(riml)
    assert_equal 0, Compiler.global_variables.count
  end

  test "variables work as expected in local and global scopes" do
    riml = <<Riml
a = "should be script local"
b:a = "should be buffer local"
def script_local_function
  a = "should be local to function"
end
Riml

    expected = <<Viml
let s:a = "should be script local"
let b:a = "should be buffer local"
function s:Script_local_function()
  let a = "should be local to function"
endfunction
Viml

    assert_equal expected, compile(riml)
    assert_equal 2, Compiler.global_variables.count
  end

  test "interpolation in double-quoted strings" do
  riml1 = '"found #{n} words"'
  expected1 = '"found " . s:n . " words"'

  riml2 = '"#{n} words were found"'
  expected2 = 's:n . " words were found"'

  # single-quoted
  riml3 = '\'#{n} words were found\''
  expected3 = '\'#{n} words were found\''

  assert_equal expected1, compile(riml1)
  assert_equal expected2, compile(riml2)
  assert_equal expected3, compile(riml3)
  end

  test "functions can take expressions" do
    riml = 'echo("found #{n} words")'
    expected = 'echo("found " . s:n . " words")' << "\n"

    assert_equal expected, compile(riml)
  end

  test "chaining method calls" do
    riml = 'n = n + len(split(getline(lnum)))'
    expected = 'let s:n = s:n + len(split(getline(s:lnum)))' << "\n"

    assert_equal expected, compile(riml)
  end

  test "function can take range when given parens" do
    riml = <<Riml
def My_function(a,b) range
end
Riml

    expected = <<Viml
function s:My_function(a, b) range
endfunction
Viml

    assert_equal expected, compile(riml)
  end

  test "function declaration parens are optional when not given arguments" do
    riml = <<Riml
def short_function
  echo("martin short")
end
Riml

    expected = <<Viml
function s:Short_function()
  echo("martin short")
endfunction
Viml

    assert_equal expected, compile(riml)
  end

  test "query at the end of variable checks for its existence" do
    riml = <<Riml
if (g:a?)
  true
end
Riml

    expected = <<Viml
if (exists?("g:a"))
  return 1
endif
Viml

    assert_equal expected, compile(riml)
  end

  test "finish keyword compiles correctly" do
    riml = <<Riml
if g:myplugin?
  finish
end
Riml

    expected = <<Viml
if (exists?("g:myplugin"))
  finish
endif
Viml

  assert_equal expected, compile(riml)
  end

  test "basic while conditional compiles correctly" do
    riml = <<Riml
i = 0
while i < 5
  echo("hi")
  i += 1
end
Riml

    expected = <<Viml
let s:i = 0
while (s:i < 5)
  echo("hi")
  s:i += 1
endwhile
Viml

  assert_equal expected, compile(riml)
  end

  test "basic lists compile correctly" do
    riml = <<Riml
alist = ["aap", "mies", "noot"]
Riml

    expected = <<Viml
let s:alist = ["aap", "mies", "noot"]
Viml

    riml2 = 'emptyList = []'
    expected2 = 'let s:emptyList = []' << "\n"

    # list concatenation
    riml3 = 'echo(alist + ["foo", "bar"])'
    expected3 = 'echo(s:alist + ["foo", "bar"])' << "\n"

  assert_equal expected, compile(riml)
  assert_equal expected2, compile(riml2)
  assert_equal expected3, compile(riml3)
  end

  test "multi dimensional lists compile correctly" do
    riml = '_2d = ["one", ["two", "three"]]'
    expected = 'let s:_2d = ["one", ["two", "three"]]' << "\n"

    riml2 = 'mult_inner_lists = [["one"], "two", "three", ["four", "five"]]'
    expected2 = 'let s:mult_inner_lists = [["one"], "two", "three", ["four", "five"]]' << "\n"

    riml3 = 'three_d = [["one"], "two", "three", ["four", "five", ["six", "seven"]]]'
    expected3 = 'let s:three_d = [["one"], "two", "three", ["four", "five", ["six", "seven"]]]' << "\n"

  assert_equal expected, compile(riml)
  assert_equal expected2, compile(riml2)
  assert_equal expected3, compile(riml3)
  end

  test "comparing strings is non ignorecase by default" do
    riml = <<Riml
string1 = "meet"
string2 = "moot"
string1 == string2
Riml

  expected = <<Viml.chomp
let s:string1 = "meet"
let s:string2 = "moot"
s:string1 ==# s:string2
Viml

  riml2 = <<Riml2
string = "meet"
number = 2
string == number
Riml2

  expected2 = <<Viml.chomp
let s:string = "meet"
let s:number = 2
s:string == s:number
Viml

  assert_equal expected, compile(riml)
  assert_equal expected2, compile(riml2)
  end

  test "basic dictionaries compile correctly" do
    riml = 'dict = {"one": "een", "two": "twee"}'
    expected = 'let s:dict = {"one": "een", "two": "twee"}' << "\n"

    riml2 = 'emptyDict = {}'
    expected2 = 'let s:emptyDict = {}' << "\n"

    riml3 = 'dictInDict = {"one": "een", ["two"]: "twee", "omg": {"who knows": "wow"}}'
    expected3 = 'let s:dictInDict = {"one": "een", ["two"]: "twee", "omg": {"who knows": "wow"}}' << "\n"

    assert_equal expected, compile(riml)
    assert_equal expected2, compile(riml2)
    assert_equal expected3, compile(riml3)
  end

  test "ternary operators compile correctly" do
    riml = 'a = b ? c : d'
    expected = 'let s:a = s:b ? s:c : s:d' << "\n"

    assert_equal expected, compile(riml)
  end

  test "for var in call() block end compiles correctly" do
    riml = <<Riml
for var in range(1,2,3)
  echo(var)
end
Riml

  expected = <<Viml.chomp
for var in range(1, 2, 3)
  echo(var)
endfor
Viml

    assert_equal expected, compile(riml)
  end
end
