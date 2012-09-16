require File.expand_path('../test_helper', __FILE__)

class BasicCompilerTest < Riml::TestCase
  Compiler = Riml::Compiler

  def setup
    Compiler.global_variables.clear
    Compiler.special_variables.clear
  end

  test "basic function compiles" do
    riml = <<Riml
def a_method(a, b)
  true
end
Riml

    nodes = Nodes.new([
      DefNode.new(nil, "a_method", ['a', 'b'], nil,
        Nodes.new([TrueNode.new])
      )
    ])

    expected = <<Viml
function! s:a_method(a, b)
  return 1
endfunction
Viml

    assert_equal expected, compile(nodes)
    assert_equal expected, compile(riml)
  end

  test "branching function compiles and returns on all branches" do
    riml = <<Riml
def b:another_method(a, b)
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
      ))
    ])

    expected = <<Viml
function! b:another_method(a, b)
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

  test "argument variable references in function bodies don't have to prefixed by a:" do
    riml = <<Riml
def s:A_method(a, b)
  if a
    echo a
  end
end
Riml

  expected = <<Viml
function! s:A_method(a, b)
  if (a:a)
    echo a:a
  endif
endfunction
Viml

    assert_equal expected, compile(riml)
  end

  test "splats are allowed in function definitions" do
    riml = <<Riml
def splat(a, b, *args)
  var = args
end
Riml

  expected = <<Viml
function! s:splat(a, b, ...)
  let var = a:000
endfunction
Viml

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
if (s:b())
  let s:a = 2
endif
Viml

    assert_equal expected, compile(nodes)
    assert_equal expected, compile(riml)
  end

  test "override riml default scipt-local scoping for variables/functions" do
    riml     =   "n:a = 'no default scoping! Hooray!'"
    expected = "let a = 'no default scoping! Hooray!'\n"
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
  echo 'hi';
end
Riml

    expected = <<Viml
if (!s:shy())
  echo 'hi'
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
function! s:script_local_function()
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
    riml = 'echo "found #{n} words"'
    expected = 'echo "found " . s:n . " words"' << "\n"

    assert_equal expected, compile(riml)
  end

  test "chaining method calls" do
    riml = 'n = n + len(split(getline(lnum)))'
    expected = 'let s:n = s:n + len(split(getline(s:lnum)))' << "\n"

    assert_equal expected, compile(riml)
  end

  test "function can take range when given parens" do
    riml = <<Riml
def My_function(a, b) range
end
Riml

    expected = <<Viml
function! s:My_function(a, b) range
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
function! s:short_function()
  echo "martin short"
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
if (exists("g:a"))
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
if (exists("g:myplugin"))
  finish
endif
Viml

  assert_equal expected, compile(riml)
  end

  test "basic while conditional compiles correctly" do
    riml = <<Riml
i = 0
while i < 5
  if skip_flag
    continue
  end
  if finished_flag
    break
  end
  echo("hi")
  i += 1
end
Riml

    expected = <<Viml
let s:i = 0
while (s:i < 5)
  if (s:skip_flag)
    continue
  endif
  if (s:finished_flag)
    break
  endif
  echo "hi"
  s:i += 1
endwhile
Viml

  assert_equal expected, compile(riml)
  end

  test "basic until conditional compiles correctly" do
    riml = <<Riml
i = 0
until i == 5
  echo("hi")
  i += 1
end
Riml

    expected = <<Viml
let s:i = 0
while (!s:i == 5)
  echo "hi"
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


  assert_equal expected, compile(riml)
  assert_equal expected2, compile(riml2)
  end

  test "list-literal concatenation" do
    riml = <<Riml
alist = ["aap", "mies"] + ["noot"]
Riml

    expected = <<Viml
let s:alist = ["aap", "mies"] + ["noot"]
Viml
    assert_equal expected, compile(riml)
  end

  test "var + literal list concatenation" do
    riml = 'echo(alist + ["foo", "bar"])'
    expected = 'echo s:alist + ["foo", "bar"]' << "\n"
    assert_equal expected, compile(riml)
  end

  test "for var in list block" do
    riml = <<Riml
for var in [1, 2, 3]
  echo var
endfor
Riml
    expected = riml
    assert_equal expected, compile(riml)
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
  echo var
endfor
Viml

    assert_equal expected, compile(riml)
  end

  test "explicitly called functions" do
    riml = <<Riml
call myFunction(arg1, arg2)
Riml

    expected = <<Viml
call s:myFunction(s:arg1, s:arg2)
Viml

    assert_equal expected, compile(riml)
  end

  test "multiple variable initialization" do
    riml = <<Riml
[a, b, c] = expression()
Riml

    expected = <<Viml
let [s:a, s:b, s:c] = s:expression()
Viml

    assert_equal expected, compile(riml)
  end

  test "special variables compile correctly" do
    riml = <<Riml
echo $VAR
@a = "register a"
&hello = "omg"
if &hello == "omg"
  echo &hello
end
echo "hi"
Riml

    expected = <<Viml
echo $VAR
let @a = "register a"
let &hello = "omg"
if (&hello ==# "omg")
  echo &hello
endif
echo "hi"
Viml
    assert_equal expected, compile(riml)
    # the types are only known for 2 of them, not $VAR
    assert_equal 2, Compiler.special_variables.values.size
  end

  test "compile line-continuations, but don't (yet) preserve spaces to keep compiled viml readable" do
riml = <<Riml
echo lnum == 1
\\     ? "top"
\\     : lnum == 1000
\\             ? "last"
\\             : lnum
Riml

expected = <<Viml
echo s:lnum == 1 ? "top" : s:lnum == 1000 ? "last" : s:lnum
Viml
    assert_equal expected, compile(riml)
  end

  test "octal, hex and floating point decimal numbers are preserved" do
    riml = "echo 0x7f + 036 + 0.1265"
    expected = riml + "\n"
    assert_equal expected, compile(riml)
  end

  test "dictionary get value for key using bracket syntax with variable" do
    riml = <<Riml
dict = {'key': 'value'}
echo dict['key']
Riml
    expected = <<Viml
let s:dict = {'key': 'value'}
echo s:dict['key']
Viml

  riml2 = <<Riml
dict = {'key': {'key2': 'value2'}}
echo dict['key']['key2']
Riml

  expected2 = <<Riml
let s:dict = {'key': {'key2': 'value2'}}
echo s:dict['key']['key2']
Riml
    assert_equal expected, compile(riml)
    assert_equal expected2, compile(riml2)
  end

  test "dictionary get value for key using bracket syntax with literal" do
    riml = <<Riml
echo {'key': 'value'}['key']
Riml
    expected = <<Viml
echo {'key': 'value'}['key']
Viml

    riml2 = <<Riml
echo {'key': {'key2': 'value2'}}['key']['key2']
Riml
    expected2 = <<Viml
echo {'key': {'key2': 'value2'}}['key']['key2']
Viml
    assert_equal expected, compile(riml)
    assert_equal expected2, compile(riml2)
  end

  test "dictionary get value for key using dot syntax with variable" do
    riml = <<Riml
dict = {'key': 'value'}
echo dict.key
Riml
    expected = <<Viml
let s:dict = {'key': 'value'}
echo s:dict.key
Viml

    riml2 = <<Riml
dict = {'key': {'key2': 'value2'}}
echo dict.key.key2
Riml
    expected2 = <<Viml
let s:dict = {'key': {'key2': 'value2'}}
echo s:dict.key.key2
Viml
    assert_equal expected, compile(riml)
    assert_equal expected2, compile(riml2)
  end

  test "dictionary get value for key using dot syntax with literal" do
    riml = <<Riml
echo {'key': 'value'}.key
Riml
   expected = <<Viml
echo {'key': 'value'}.key
Viml

    riml2 = <<Riml
echo {'key': {'key2': 'value2'}}.key.key2
Riml
   expected2 = <<Viml
echo {'key': {'key2': 'value2'}}.key.key2
Viml
    assert_equal expected, compile(riml)
    assert_equal expected2, compile(riml2)
  end

  test "dictionary set value for key with variable" do
    riml = <<Riml
dict = {'key': {'key2': 'value2'}}
let dict.key = {'key3': 'value3'}
Riml
    expected = <<Viml
let s:dict = {'key': {'key2': 'value2'}}
let s:dict.key = {'key3': 'value3'}
Viml
    assert_equal expected, compile(riml)
  end

  test "list or dict get with variable" do
    riml = <<Riml
val = list_or_dict[0]
Riml
    expected = <<Viml
let s:val = s:list_or_dict[0]
Viml

    riml2 = <<Riml
val = list_or_dict[0][2]
Riml
    expected2 = <<Viml
let s:val = s:list_or_dict[0][2]
Viml

    riml3 = <<Riml
val = list_or_dict[method()]['key']
Riml
    expected3 = <<Viml
let s:val = s:list_or_dict[s:method()]['key']
Viml

    riml4 = <<Riml
val = list_or_dict[dict.key][2]
Riml
    expected4 = <<Viml
let s:val = s:list_or_dict[s:dict.key][2]
Viml

    assert_equal expected, compile(riml)
    assert_equal expected2, compile(riml2)
    assert_equal expected3, compile(riml3)
    assert_equal expected4, compile(riml4)
  end

  test "list or dict get with a dict get" do
    riml = <<Riml
val = dict.get[0]
Riml
    expected = <<Viml
let s:val = s:dict.get[0]
Viml

    riml2 = <<Riml
val = dict.get[dict.key]['key']
Riml
    expected2 = <<Viml
let s:val = s:dict.get[s:dict.key]['key']
Viml

    riml3 = <<Riml
val = dict.get[method()][2]
Riml
    expected3 = <<Viml
let s:val = s:dict.get[s:method()][2]
Viml
    assert_equal expected, compile(riml)
    assert_equal expected2, compile(riml2)
    assert_equal expected3, compile(riml3)
  end

  test "list or dict get with a call" do
    riml = <<Riml
val = method()[0]
Riml
    expected = <<Viml
let s:val = s:method()[0]
Viml

    riml2 = <<Riml
val = method()[dict.key]['key']
Riml
    expected2 = <<Viml
let s:val = s:method()[s:dict.key]['key']
Viml

    riml3 = <<Riml
val = method()[other_method()][2]
Riml
    expected3 = <<Viml
let s:val = s:method()[s:other_method()][2]
Viml
    assert_equal expected, compile(riml)
    assert_equal expected2, compile(riml2)
    assert_equal expected3, compile(riml3)
  end

  test "curly-braces variable names" do
    riml = <<Riml
echo my_{background}_message
Riml

    expected = <<Viml
echo s:my_{s:background}_message
Viml

riml2 = <<Riml
echo my_{&background}_message
Riml
    expected2 = <<Viml
echo s:my_{&background}_message
Viml
    assert_equal expected, compile(riml)
    assert_equal expected2, compile(riml2)
  end

  test "curly-braces function definition" do
    riml = <<Riml
def my_{background}_message(param)
  echo param
end
Riml

    expected = <<Viml
function! s:my_{s:background}_message(param)
  echo a:param
endfunction
Viml
    assert_equal expected, compile(riml)
  end

  test "curly-braces function call" do
    riml = <<Riml
n:param = 2
call my_{background}_message(n:param)
Riml

    expected = <<Viml
let param = 2
call s:my_{s:background}_message(param)
Viml
    assert_equal expected, compile(riml)
  end

  test "basic try block" do
    riml = <<Riml
try
  a = 2
catch
  echo "error"
end
Riml

    expected = <<Viml
try
  let s:a = 2
catch
  echo "error"
endtry
Viml
    assert_equal expected, compile(riml)
  end
end
