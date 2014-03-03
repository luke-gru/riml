require File.expand_path('../test_helper', __FILE__)

module Riml
class BasicCompilerTest < Riml::TestCase

  test "basic function compiles" do
    riml = <<Riml
def a_method(a, b)
  return true
end
Riml

    nodes = Nodes.new([
      DefNode.new('!', nil, nil, "a_method", ['a', 'b'], nil,
        Nodes.new([ ReturnNode.new(TrueNode.new) ])
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

  test "branching function compiles" do
    riml = <<Riml
def b:another_method(a, b)
  if hello()
    false
  else
    true
  end
  call SomeFunction()
end
Riml

    nodes = Nodes.new([
      DefNode.new('!', nil, 'b:', "another_method", ['a', 'b'], nil, Nodes.new([
        IfNode.new(CallNode.new(nil, "hello", []), Nodes.new([
          FalseNode.new, ElseNode.new(Nodes.new([TrueNode.new]))])),
        ExplicitCallNode.new(nil, "SomeFunction", [])
        ])
      )
    ])

    expected = <<Viml
function! b:another_method(a, b)
  if s:hello()
    0
  else
    1
  endif
  call s:SomeFunction()
endfunction
Viml

    assert_equal expected, compile(nodes)
    assert_equal expected, compile(riml)
  end

  test "if function with more complicated conditional" do
    riml = <<Riml
if exists("g:loaded_pathogen") || &cp
  finish
endif
Riml

    expected = <<Viml
if exists("g:loaded_pathogen") || &cp
  finish
endif
Viml
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
  if a:a
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
          [AssignNode.new("=", GetVariableNode.new(nil, "a"), NumberNode.new(2))]
        )
      )
    ])

  expected = <<Viml
if s:b()
  let s:a = 2
endif
Viml

    assert_equal expected, compile(nodes)
    assert_equal expected, compile(riml)
  end

  test "if statement modifier" do
    riml = <<Riml
a = 3 if a == 0
Riml

    expected = <<Viml
if s:a ==# 0
  let s:a = 3
endif
Viml
    assert_equal expected, compile(riml)
  end

  test "if statement modifier after return void" do
    riml = <<Riml
return if returnEarly == true
Riml

    expected = <<Viml
if s:returnEarly ==# 1
  return
endif
Viml
    assert_equal expected, compile(riml)
  end

  test "if statement modifier after return value" do
    riml = <<Riml
return false if returnEarly == true
Riml

    expected = <<Viml
if s:returnEarly ==# 1
  return 0
endif
Viml
    assert_equal expected, compile(riml)
  end

  test "override riml default scipt-local scoping for variables/functions" do
    riml     =   "n:a = 'no default scoping! Hooray!'"
    expected = "let a = 'no default scoping! Hooray!'\n"
    assert_equal expected, compile(riml)
  end

  test "unlet works" do
    riml = "unlet b:a"
    expected = "unlet! b:a"

    riml2 = "unlet b:a b:b b:c"
    expected2 = "unlet! b:a b:b b:c"

    assert_equal expected, compile(riml)
    assert_equal expected2, compile(riml2)
  end

  test "unless expression always wraps the condition in parens to avoid ! operator ambiguity" do
    riml = <<Riml
unless shy()
  echo 'hi';
end
Riml

    expected = <<Viml
if !(s:shy())
  echo 'hi'
endif
Viml

    assert_equal expected, compile(riml)
  end

  test "unless expression doesn't wrap in parens again if already wrapped" do
    riml = <<Riml
unless (shy())
  echo 'hi';
end
Riml

    expected = <<Viml
if !(s:shy())
  echo 'hi'
endif
Viml

    assert_equal expected, compile(riml)
  end

  test "until expression always wraps the condition in parens to avoid ! operator ambiguity" do
    riml = <<Riml
until sober() || asleep()
  echo 'Party Hard!'
end
Riml

    expected = <<Viml
while !(s:sober() || s:asleep())
  echo 'Party Hard!'
endwhile
Viml

    assert_equal expected, compile(riml)
  end

  test "until expression doesn't wrap in parens again if already wrapped" do
    riml = <<Riml
until (sober() || asleep())
  echo 'Party Hard!'
end
Riml

    expected = <<Viml
while !(s:sober() || s:asleep())
  echo 'Party Hard!'
endwhile
Viml

    assert_equal expected, compile(riml)
  end

  test "variables work as expected in local and global scopes" do
    riml = <<Riml
a = "should be script local"
b:a = "should be buffer local"
def script_local_function()
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

  test "interpolation with any expressions, not just variables" do
    riml = '"I think his name was... #{guess()}"'
    expected = '"I think his name was... " . s:guess()'

    assert_equal expected, compile(riml)
  end

  test "more than one interpolated expression in double quoted string" do
    riml = '"I think #{(gender == \'m\' ? \'his\' : \'her\')} name was... #{guess()}"'
    expected = '"I think " . (s:gender ==# \'m\' ? \'his\' : \'her\') . " name was... " . s:guess()'

    assert_equal expected, compile(riml)
  end

  # :h expr-quote
  test "double-quoted string escape sequences" do
    escape_sequences = [
      '\n', '\r', '\f', '\316', '\07', '\7', '\x1f',
      '\xf', '\X1f', '\Xf', '\u02a4', '\U02a4', '\b',
      '\e', '\t', '\"', '\\\\' '\<C-W>'
    ]
    escape_sequences.each do |sequence|
      riml = "voice = \"hey dude!#{sequence}\""
      expected = "let s:voice = \"hey dude!#{sequence}\""
      assert_equal expected, compile(riml).chomp
    end
  end

  test "functions can take expressions" do
    riml = 'echo "found #{n} words"'
    expected = 'echo "found " . s:n . " words"'

    assert_equal expected, compile(riml).chomp
  end

  test "chaining method calls" do
    riml = 'n = n + len(split(getline(lnum)))'
    expected = 'let s:n = s:n + len(split(getline(s:lnum)))'

    assert_equal expected, compile(riml).chomp
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
  1
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
if exists("g:myplugin")
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
while s:i <# 5
  if s:skip_flag
    continue
  endif
  if s:finished_flag
    break
  endif
  echo "hi"
  let s:i += 1
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
while !(s:i ==# 5)
  echo "hi"
  let s:i += 1
endwhile
Viml

  assert_equal expected, compile(riml)
  end

  test "until with two expressions in conditional takes into account paren grouping" do
    riml = <<Riml
i = 0
until i == 5 || i == 3
  echo s:i
  i += 1
end
Riml

    expected = <<Viml
let s:i = 0
while !(s:i ==# 5 || s:i ==# 3)
  echo s:i
  let s:i += 1
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
    expected2 = 'let s:emptyList = []'


  assert_equal expected, compile(riml)
  assert_equal expected2, compile(riml2).chomp
  end

  test "lists can take optional comma at end if not empty" do
    riml = <<Riml
alist = ["aap", "mies", "noot",]
Riml

    expected = <<Viml
let s:alist = ["aap", "mies", "noot"]
Viml
  assert_equal expected, compile(riml)
  end

  test "list unpack" do
    riml = <<Riml
let [var1, var2, last] = mylist
Riml

    expected = <<Viml
let [s:var1, s:var2, s:last] = s:mylist
Viml

    assert_equal expected, compile(riml)
  end

  test "list unpack with rest" do
    riml = <<Riml
let [var1, var2; rest] = mylist
Riml

    expected = <<Viml
let [s:var1, s:var2; s:rest] = s:mylist
Viml

    assert_equal expected, compile(riml)
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
    expected = 'echo s:alist + ["foo", "bar"]'
    assert_equal expected, compile(riml).chomp
  end

  test "for var in list block in global scope without explicit scope modifier" do
    riml = <<Riml
for var in [1, 2, 3]
  echo var
endfor
echo "done"
Riml

    expected = <<Viml
for s:var in [1, 2, 3]
  echo s:var
endfor
echo "done"
Viml
    assert_equal expected, compile(riml)
  end

  test "for var in list block in global scope with explicit scope modifier" do
    riml = <<Riml
for s:var in [1, 2, 3]
  echo s:var
endfor
echo "done"
Riml

    expected = <<Viml
for s:var in [1, 2, 3]
  echo s:var
endfor
echo "done"
Viml
    assert_equal expected, compile(riml)
  end

  test "for list in multi-list" do
    riml = <<Riml
for [lnum, col] in [[1, 3], [2, 8], [3, 0]]
  call Doit(lnum, col)
endfor
Riml
    expected = <<Viml
for [s:lnum, s:col] in [[1, 3], [2, 8], [3, 0]]
  call s:Doit(s:lnum, s:col)
endfor
Viml

    assert_equal expected, compile(riml)
  end

  test "for list-unpack in expr" do
    riml = <<Riml
for [i, j; rest] in listlist
  call Doit(i, j)
  if !empty(rest)
    echo "remainder: " . string(rest)
  endif
endfor
Riml

    expected = <<Viml
for [s:i, s:j; s:rest] in s:listlist
  call s:Doit(s:i, s:j)
  if !empty(s:rest)
    echo "remainder: " . string(s:rest)
  endif
endfor
Viml

    assert_equal expected, compile(riml)
  end

  test "for var in function scope without explicit scope modifier" do
    riml = <<Riml
def func
  for num in range(7)
    echo num
  end
end
Riml

    expected = <<Viml
function! s:func()
  for num in range(7)
    echo num
  endfor
endfunction
Viml
    assert_equal expected, compile(riml)
  end

  test "for var in function scope with explicit scope modifier" do
    riml = <<Riml
def func
  for s:num in range(7)
    echo s:num
  end
end
Riml

    expected = <<Viml
function! s:func()
  for s:num in range(7)
    echo s:num
  endfor
endfunction
Viml
    assert_equal expected, compile(riml)
  end

  test "for var in function scope with explicit scope modifier and shadowing outer local variable" do
    riml = <<Riml
def func
  num = 1
  for s:num in range(7)
    echo num " should echo 1 always
  end
end
Riml

    expected = <<Viml
function! s:func()
  let num = 1
  for s:num in range(7)
    echo num
  endfor
endfunction
Viml
    assert_equal expected, compile(riml)
  end

  test "multi dimensional lists compile correctly" do
    riml = '_2d = ["one", ["two", "three"]]'
    expected = 'let s:_2d = ["one", ["two", "three"]]'

    riml2 = 'mult_inner_lists = [["one"], "two", "three", ["four", "five"]]'
    expected2 = 'let s:mult_inner_lists = [["one"], "two", "three", ["four", "five"]]'

    riml3 = 'three_d = [["one"], "two", "three", ["four", "five", ["six", "seven"]]]'
    expected3 = 'let s:three_d = [["one"], "two", "three", ["four", "five", ["six", "seven"]]]'

  assert_equal expected, compile(riml).chomp
  assert_equal expected2, compile(riml2).chomp
  assert_equal expected3, compile(riml3).chomp
  end


  test "comparing literals is non ignorecase by default" do
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
s:string ==# s:number
Viml

  assert_equal expected, compile(riml)
  assert_equal expected2, compile(riml2)
  end

  test "positive exponents work" do
    riml = "echo 1.4e10"
    riml2 = "echo 1.4e+10"
    assert_equal riml, compile(riml).chomp
    assert_equal riml2, compile(riml2).chomp
  end

  test "negative exponents" do
    riml = "echo 1.4e-10"
    assert_equal riml, compile(riml).chomp
  end

  test "basic dictionaries compile correctly" do
    riml = 'dict = {"one": "een", "two": "twee"}'
    expected = 'let s:dict = {"one": "een", "two": "twee"}'

    riml2 = 'emptyDict = {}'
    expected2 = 'let s:emptyDict = {}'

    # dictionary with optional comma at the end
    riml3 = 'dictInDict = {"one": "een", ["two"]: "twee", "omg": {"who knows": "wow",},}'
    expected3 = 'let s:dictInDict = {"one": "een", ["two"]: "twee", "omg": {"who knows": "wow"}}'

    assert_equal expected, compile(riml).chomp
    assert_equal expected2, compile(riml2).chomp
    assert_equal expected3, compile(riml3).chomp
  end

  test "ternary operators compile correctly" do
    riml = 'a = b ? c : d'
    expected = 'let s:a = s:b ? s:c : s:d'

    assert_equal expected, compile(riml).chomp
  end

  test "unary NOT operator compiles correctly" do
    riml = <<Riml
if (!has_key(nrule, 'mode'))
  let nrule.mode = 'i'
endif
Riml

    expected = <<Viml
if (!has_key(s:nrule, 'mode'))
  let s:nrule.mode = 'i'
endif
Viml
    assert_equal expected, compile(riml)
  end

  test "unary NOT takes into account parens" do
    riml = <<Riml
if !(has_key(nrule, 'mode') || has_key(nrule, 'other'))
  let nrule.mode  = 'i'
  let nrule.other = 'j'
endif
Riml

    expected = <<Viml
if !(has_key(s:nrule, 'mode') || has_key(s:nrule, 'other'))
  let s:nrule.mode = 'i'
  let s:nrule.other = 'j'
endif
Viml
    assert_equal expected, compile(riml)
  end

  test "for var in call() block end compiles correctly" do
    riml = <<Riml
for var in range(1,2,3)
  echo(var)
end
Riml

    expected = <<Viml
for s:var in range(1, 2, 3)
  echo s:var
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
if &hello ==# "omg"
  echo &hello
endif
echo "hi"
Viml
    assert_equal expected, compile(riml)
  end

  test "register variables compile correctly" do
    Riml::Constants::REGISTERS.each do |reg|
      riml = "@#{reg} = 'val'"
      expected = "let @#{reg} = 'val'"
      assert_equal expected, compile(riml).chomp
    end
  end

  test "options prefixed with scope (:help expr-option)" do
    riml = "echo &g:option"
    riml2 = "echo &l:option"

    assert_equal riml, compile(riml).chomp
    assert_equal riml2, compile(riml2).chomp
  end

  test "get and set variable with scope literal and key" do
    riml = "echo s:[key]"
    riml2 = "g:['key'] = val"

    expected = "echo s:[s:key]"
    expected2 = "let g:['key'] = s:val"

    assert_equal expected, compile(riml).chomp
    assert_equal expected2, compile(riml2).chomp
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
echo s:lnum ==# 1 ? "top" : s:lnum ==# 1000 ? "last" : s:lnum
Viml
    assert_equal expected, compile(riml)
  end

  test "octal, hex and floating point decimal numbers are preserved" do
    riml = "echo 0x7f + 036 + 0.1265"
    expected = riml
    assert_equal expected, compile(riml).chomp
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
    expected = <<Viml.chomp
echo {'key': 'value'}['key']
Viml

    riml2 = <<Riml
echo {'key': {'key2': 'value2'}}['key']['key2']
Riml
    expected2 = <<Viml.chomp
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

  test "dictionary set value for key with dot syntax" do
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

  test "set value for key using bracket syntax" do
    riml = <<Riml
dict = {'key': {'key2': 'value2'}}
let myKey = 'key'
let dict[myKey] = {'key3': 'value3'}
Riml
    expected = <<Viml
let s:dict = {'key': {'key2': 'value2'}}
let s:myKey = 'key'
let s:dict[s:myKey] = {'key3': 'value3'}
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

  test "list or dict get with parenthesized ternary operator" do
    riml = <<Riml
val = (len(list) > 1 ? list1 : list2)[0]
Riml
    expected = <<Viml
let s:val = (len(s:list) ># 1 ? s:list1 : s:list2)[0]
Viml
    assert_equal expected, compile(riml)
  end

  test "list or dict get with parenthesized binary operator" do
    riml = <<Riml
val = (dir . sep)[0]
Riml
    expected = <<Viml
let s:val = (s:dir . s:sep)[0]
Viml
    assert_equal expected, compile(riml)
  end

  test "dict get with parenthesized ternary operator" do
    riml = <<Riml
echo (len(list) > 1 ? {"a": "dict"} : {"a": "notherDict"}).a
Riml
    expected = <<Viml
echo (len(s:list) ># 1 ? {"a": "dict"} : {"a": "notherDict"}).a
Viml
    assert_equal expected, compile(riml)
  end

  test "dict get with parenthesized binary operator" do
    riml = <<Riml
echo (dict1 && dict2).key
Riml
    expected = <<Viml
echo (s:dict1 && s:dict2).key
Viml
    assert_equal expected, compile(riml)
  end

  test "curly-braces variable names" do
    riml = <<Riml
echo my_{background}_message
Riml

    expected = <<Viml
echo s:my_{s:background}_message
Viml

riml2 = <<Riml
echo my_{&background}_{&other}_message
Riml
    expected2 = <<Viml
echo s:my_{&background}_{&other}_message
Viml
    assert_equal expected, compile(riml)
    assert_equal expected2, compile(riml2)
  end

  test "nested curly-brace variable names" do
    riml = <<Riml
call my_{&color{size}}_fn()
Riml

    expected = <<Viml
call s:my_{&color{s:size}}_fn()
Viml
    riml2 = <<Riml
call my_{color{size}}_fn()
Riml

    expected2 = <<Viml
call s:my_{s:color{s:size}}_fn()
Viml

    riml3 = <<Riml
let bright{color} = 255
Riml

    expected3 = <<Viml
let s:bright{s:color} = 255
Viml

    riml4 = <<Riml
let {n:color} = 100
Riml

    expected4 = <<Viml
let s:{color} = 100
Viml
    assert_equal expected,  compile(riml)
    assert_equal expected2, compile(riml2)
    assert_equal expected3, compile(riml3)
    assert_equal expected4, compile(riml4)
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

  test "define dictionary method" do
    riml = <<Riml
myDict = {'msg': 'hey'}
function! myDict.echoMsg()
  echo self.msg
end
Riml

    expected = <<Viml
let s:myDict = {'msg': 'hey'}
function! s:myDict.echoMsg() dict
  echo self.msg
endfunction
Viml
    assert_equal expected, compile(riml)
  end

  test "define dictionary method with curly-brace name raises InvalidMethodDefinition" do
    riml = <<Riml
myDict = {'msg': 'hey'}
funcName = 'echoMsg'
def myDict.{funcName}()
  echo self.msg
end
Riml

    assert_raises(Riml::InvalidMethodDefinition) do
      compile(riml)
    end
  end

  test "curly brace name function that is nested within another function uses proper variable name scope modifier" do

    riml = <<Riml
class Mock
  defm expects(method_name)
    add(self.expected_calls, method_name)
    def s:mocked_{method_name}(*args) dict " testing that `method_name` has proper 'a:' scope modifier
      " get methodname ...
      self.method_called(methodname, args)
    end
    self[method_name] = function("s:mocked_\#{method_name}")
  end
end
Riml

    expected = <<Viml
function! s:MockConstructor()
  let mockObj = {}
  let mockObj.expects = function('<SNR>' . s:SID() . '_s:Mock_expects')
  return mockObj
endfunction
function! <SID>s:Mock_expects(method_name) dict
  call add(self.expected_calls, a:method_name)
  function! s:mocked_{a:method_name}(...) dict
    call self.method_called(methodname, a:000)
  endfunction
  let self[a:method_name] = function(\"s:mocked_\" . a:method_name)
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

  test "basic regular expression" do
    riml = <<Riml
regex = /(.*)/
Riml

    expected = <<Viml
let s:regex = /(.*)/
Viml
    assert_equal expected, compile(riml)
  end

  test "regular expression with simple forward-slash escape" do
    riml = <<Riml
regex = /\/\(.*\)/
Riml

    expected = <<Viml
let s:regex = /\/\(.*\)/
Viml
    assert_equal expected, compile(riml)
  end

  test "try block with catch (regexp) and finally" do
    riml = <<Riml
try
  a = 2
catch /E484:/
  echo "error 484"
finally
  echo "always"
end
Riml

    expected = <<Viml
try
  let s:a = 2
catch /E484:/
  echo "error 484"
finally
  echo "always"
endtry
Viml
    assert_equal expected, compile(riml)
  end

  test "try block with multiple catches" do
    riml = <<Riml
try
  a = 2
catch /E484:/
  echo "error 484"
catch /E485:/
  echo "Oh. My. Gawd! Not error 485!!!"
end
Riml

    expected = <<Viml
try
  let s:a = 2
catch /E484:/
  echo "error 484"
catch /E485:/
  echo "Oh. My. Gawd! Not error 485!!!"
endtry
Viml
    assert_equal expected, compile(riml)
  end

  test "catch with empty regexp" do
    riml = <<Riml
try
catch //
end
Riml
    expected = <<Viml
try
catch //
endtry
Viml
    assert_equal expected, compile(riml)
  end

  test "catch with string pattern" do
    riml = <<Riml
try
catch 'Error'
end
Riml
    expected = <<Viml
try
catch 'Error'
endtry
Viml
    assert_equal expected, compile(riml)
  end

  test "ex-literals (lines starting with ':') don't get translated at all except for deleted ':' at beg. of line" do
    riml     = <<Riml
:autocmd BufEnter * quit!
:autocmd BufEnter *.html split
Riml
    expected = riml.gsub(/^:/, '')

    assert_equal expected, compile(riml)
  end

  test "set variable to value of binary == expression" do
    riml = <<Riml
a = "hi" == "hi"
Riml

    expected = <<Viml
if "hi" ==# "hi"
  let s:a = 1
else
  let s:a = 0
endif
Viml
    assert_equal expected, compile(riml)
  end

  test "set variable to value of binary =~ expression" do
    riml = <<Riml
b = "hi" =~ /hi/
Riml

    expected = <<Viml
if "hi" =~# /hi/
  let s:b = 1
else
  let s:b = 0
endif
Viml
    assert_equal expected, compile(riml)
  end

  test "heredoc string" do
    riml = '
heredoc = <<EOS
omg this is a heredoc
EOS
'.strip

    expected = %{let s:heredoc = "omg this is a heredoc"}

    assert_equal expected, compile(riml).chomp
  end

  test "heredoc with interpolation" do
    riml = '
heredoc = <<EOS
Hello there, #{name}, how are you?
EOS
'.strip

    expected = %{let s:heredoc = "Hello there, " . s:name . ", how are you?"}

    assert_equal expected, compile(riml).chomp
  end

  test "heredoc with more than one interpolated expression" do
    riml = '
lineFromMovie = <<EOS
Holy #{loudExpletive()} it\'s freaking #{superhero}!
EOS
'.strip

    expected = %{let s:lineFromMovie = "Holy " . s:loudExpletive() . " it's freaking " . s:superhero . "!"}

    assert_equal expected, compile(riml).chomp
  end

  test "multiline (poetic) heredoc" do
    riml = <<Riml
poem = <<endpoem
M
u
l
tiline\\n
endpoem
Riml
    expected = <<Viml
let s:poem = "M\\nu\\nl\\ntiline\\n"
Viml
    assert_equal expected, compile(riml)
  end

  test "interpolation in multiline heredoc" do
    riml = <<Riml
dogTalk = <<EOS
hey there cute
\#{dog.breed}
EOS
Riml
    expected = <<Viml
let s:dogTalk = "hey there cute\\n" . s:dog.breed
Viml
    assert_equal expected, compile(riml)
  end

  test "double quotes in heredocs get escaped with interpolation" do
    riml = '
lineFromMovie = <<EOS
Holy "#{loudExpletive()}" it\'s freaking #{superhero}!
EOS
'.strip

    expected = %{let s:lineFromMovie = "Holy \\"" . s:loudExpletive() . "\\" it's freaking " . s:superhero . "!"}

    assert_equal expected, compile(riml).chomp
  end

  test "double quotes get escaped in heredocs without interpolation" do
    riml = '
quote = <<EOS
"I still watch Duckman!"
EOS
'.strip

    expected = %{let s:quote = "\\"I still watch Duckman!\\""}

    assert_equal expected, compile(riml).chomp
  end

  test "back-to-back interpolations" do
    riml = <<Riml
host = "Tom Scharpling"
title = "The Best Show on WFMU with \#{host}\#{(guests ? ' and guests' : '')}"
Riml

    expected = <<Riml
let s:host = "Tom Scharpling"
let s:title = "The Best Show on WFMU with " . s:host . (s:guests ? ' and guests' : '')
Riml
    assert_equal expected, compile(riml)
  end

  test "back-to-back interpolations in heredoc" do
    riml = '
host = "Tom Scharpling"
title = <<EOS
The Best Show on WFMU with #{host}#{(guests ? \' and guests\' : \'\')}
EOS
'.strip
    expected = <<Riml
let s:host = "Tom Scharpling"
let s:title = "The Best Show on WFMU with " . s:host . (s:guests ? ' and guests' : '')
Riml
    assert_equal expected, compile(riml)
  end

  test "back-to-back interpolations in heredoc with more string literal after" do
    riml = '
host = "Tom Scharpling"
title = <<EOS
The Best Show on WFMU with #{host}#{(guests ? \' and guests\' : \'\')} and others
EOS
'.strip
    expected = <<Riml
let s:host = "Tom Scharpling"
let s:title = "The Best Show on WFMU with " . s:host . (s:guests ? ' and guests' : '') . " and others"
Riml
    assert_equal expected, compile(riml)
  end

  test "autoloadable variables" do
    riml = <<Riml
l = some#path#to#var
Riml

    expected = <<Viml
let s:l = s:some#path#to#var
Viml
    assert_equal expected, compile(riml)
  end

  test "strict equals comparison" do
    riml = <<Riml
if ("string" === 0)
  echo "never get here"
end
Riml

    expected = <<Viml
if (["string"] ==# [0])
  echo "never get here"
endif
Viml
    assert_equal expected, compile(riml)
  end

  test "set list item to result of expr" do
    riml = <<Riml
let list[item] = expr()
Riml

    expected = <<Viml
let s:list[s:item] = s:expr()
Viml
    assert_equal expected, compile(riml)
  end

  test "list sublists" do
    riml = <<Riml
let myList = otherList[0:-1]
Riml

    expected = <<Viml
let s:myList = s:otherList[0 : -1]
Viml

    assert_equal expected, compile(riml)
  end

  test "set sublist items to result of expr" do
    riml = <<Riml
let list[0:-1] = expr()
Riml

    expected = <<Viml
let s:list[0 : -1] = s:expr()
Viml
    assert_equal expected, compile(riml)
  end

  test "basic class definition" do
    riml = <<Riml
class MyClass
  def initialize(arg1, arg2, *args)
  end
end
Riml

    expected = <<Viml
function! s:MyClassConstructor(arg1, arg2, ...)
  let myClassObj = {}
  return myClassObj
endfunction
Viml
    assert_equal expected, compile(riml)
  end

  test "class definition with initialize function" do
    riml = <<Riml
class MyClass
  def initialize(arg1, arg2, *args)
    self.name = arg1
    self.country = arg2
    self.lastArg = args[0] if args[0]
  end
end
Riml

    expected = <<Viml
function! s:MyClassConstructor(arg1, arg2, ...)
  let myClassObj = {}
  let myClassObj.name = a:arg1
  let myClassObj.country = a:arg2
  if a:000[0]
    let myClassObj.lastArg = a:000[0]
  endif
  return myClassObj
endfunction
Viml
    assert_equal expected, compile(riml)
  end

  test "classes with methods" do
    riml = <<Riml
class MyClass
  def initialize(arg1, arg2, *args)
  end

  defm getData
    return self.data
  end

  defm getOtherData
    return self.otherData
  end
end
Riml

    expected = <<Viml
function! s:MyClassConstructor(arg1, arg2, ...)
  let myClassObj = {}
  let myClassObj.getData = function('<SNR>' . s:SID() . '_s:MyClass_getData')
  let myClassObj.getOtherData = function('<SNR>' . s:SID() . '_s:MyClass_getOtherData')
  return myClassObj
endfunction
function! <SID>s:MyClass_getData() dict
  return self.data
endfunction
function! <SID>s:MyClass_getOtherData() dict
  return self.otherData
endfunction
Viml

    assert_equal expected, compile(riml)
  end

  test "classes that inherit" do
    riml = <<Riml
class Translation
  def initialize(input)
    self.input = input
  end
end

class FrenchToEnglishTranslation < Translation
  defm translate
    if self.input == "Bonjour!"
      echo "Hello!"
    else
      echo "Sorry, I don't know that word."
    end
  end
end

translation = new FrenchToEnglishTranslation("Bonjour!")
translation.translate()
Riml

    expected = <<Viml
function! s:TranslationConstructor(input)
  let translationObj = {}
  let translationObj.input = a:input
  return translationObj
endfunction
function! s:FrenchToEnglishTranslationConstructor(input)
  let frenchToEnglishTranslationObj = {}
  let translationObj = s:TranslationConstructor(a:input)
  call extend(frenchToEnglishTranslationObj, translationObj)
  let frenchToEnglishTranslationObj.translate = function('<SNR>' . s:SID() . '_s:FrenchToEnglishTranslation_translate')
  return frenchToEnglishTranslationObj
endfunction
function! <SID>s:FrenchToEnglishTranslation_translate() dict
  if self.input ==# "Bonjour!"
    echo "Hello!"
  else
    echo "Sorry, I don't know that word."
  endif
endfunction
let s:translation = s:FrenchToEnglishTranslationConstructor("Bonjour!")
call s:translation.translate()
Viml

    assert_equal expected, compile(riml)
  end

  test "ClassNotFound raised when instantiating class that doesn't exist" do
    riml = <<Riml
pup = new Puppy()
Riml

    assert_raises(ClassNotFound) do
      compile(riml)
    end
  end

  test "allow instantiating class without parens after constructor function" do
    riml = <<Riml
class Dog
end
d = new Dog
Riml

    expected = <<Viml
function! s:DogConstructor()
  let dogObj = {}
  return dogObj
endfunction
let s:d = s:DogConstructor()
Viml

    assert_equal expected, compile(riml)
  end

  test "super with parens in initialize function" do
    riml = <<Riml
class Car
  def initialize(make, model, color)
    self.make = make
    self.model = model
    self.color = color
  end
end

class HotRod < Car
  def initialize(make, model, color, topSpeed)
    self.topSpeed = topSpeed
    super(make, model, color)
  end

  defm drive
    if self.topSpeed > 140
      echo "Ahhhhhhh!"
    else
      echo "Nice"
    end
  end
end

newCar = new HotRod("chevy", "mustang", "red", 160)
newCar.drive()
Riml

    expected = <<Viml
function! s:CarConstructor(make, model, color)
  let carObj = {}
  let carObj.make = a:make
  let carObj.model = a:model
  let carObj.color = a:color
  return carObj
endfunction
function! s:HotRodConstructor(make, model, color, topSpeed)
  let hotRodObj = {}
  let hotRodObj.topSpeed = a:topSpeed
  let carObj = s:CarConstructor(a:make, a:model, a:color)
  call extend(hotRodObj, carObj)
  let hotRodObj.drive = function('<SNR>' . s:SID() . '_s:HotRod_drive')
  return hotRodObj
endfunction
function! <SID>s:HotRod_drive() dict
  if self.topSpeed ># 140
    echo "Ahhhhhhh!"
  else
    echo "Nice"
  endif
endfunction
let s:newCar = s:HotRodConstructor("chevy", "mustang", "red", 160)
call s:newCar.drive()
Viml
    assert_equal expected, compile(riml)
  end

  test "super without parens in initialize function passes all arguments" do
    riml = <<Riml
class A
  def initialize(foo, bar)
    self.foo = foo
    self.bar = bar
  end
end

class B < A
  def initialize(foo, bar)
    super
    self.other = totalCost(foo, bar)
  end
end
Riml

    expected = <<Viml
function! s:AConstructor(foo, bar)
  let aObj = {}
  let aObj.foo = a:foo
  let aObj.bar = a:bar
  return aObj
endfunction
function! s:BConstructor(foo, bar)
  let bObj = {}
  let aObj = s:AConstructor(a:foo, a:bar)
  call extend(bObj, aObj)
  let bObj.other = s:totalCost(a:foo, a:bar)
  return bObj
endfunction
Viml

    assert_equal expected, compile(riml)
  end

  test "implicit super works when inside initialize function that's given a splat parameter" do
    riml = <<Riml
class A
  def initialize(foo, *options)
    self.foo = foo
    self.options = options
  end
end

class B < A
  def initialize(foo, *options)
    self.other = calculateOther()
    super
  end
end
Riml

    expected = <<Viml
function! s:AConstructor(foo, ...)
  let aObj = {}
  let aObj.foo = a:foo
  let aObj.options = a:000
  return aObj
endfunction
function! s:BConstructor(foo, ...)
  let bObj = {}
  let bObj.other = s:calculateOther()
  let aObj = s:AConstructor(a:foo, a:000)
  call extend(bObj, aObj)
  return bObj
endfunction
Viml

    assert_equal expected, compile(riml)
  end

  test "super works in non initialize functions" do
    riml = <<Riml
class Job
  defm doIt()
    echo "Doing job \#{speed}."
  end
  defm setSpeed(speed)
    self.speed = speed
  end
end

class FastJob < Job
  defm doIt()
    self.setSpeed('fast')
    super
  end
end
Riml

    expected = <<Viml
function! s:JobConstructor()
  let jobObj = {}
  let jobObj.doIt = function('<SNR>' . s:SID() . '_s:Job_doIt')
  let jobObj.setSpeed = function('<SNR>' . s:SID() . '_s:Job_setSpeed')
  return jobObj
endfunction
function! <SID>s:Job_doIt() dict
  echo "Doing job " . speed . "."
endfunction
function! <SID>s:Job_setSpeed(speed) dict
  let self.speed = a:speed
endfunction
function! s:FastJobConstructor()
  let fastJobObj = {}
  let jobObj = s:JobConstructor()
  call extend(fastJobObj, jobObj)
  let fastJobObj.doIt = function('<SNR>' . s:SID() . '_s:FastJob_doIt')
  let fastJobObj.Job_doIt = function('<SNR>' . s:SID() . '_s:Job_doIt')
  return fastJobObj
endfunction
function! <SID>s:FastJob_doIt() dict
  call self.setSpeed('fast')
  call self.Job_doIt()
endfunction
Viml

    assert_equal expected, compile(riml)
  end

  test "raises error when calling super but no method of that name exists in superclass(es)" do
    riml = <<Riml
class Job
  defm doIt(speed)
    echo "Doing job"
  end
  defm setSpeed(speed)
    self.speed = speed
  end
end

class FastJob < Job
  defm doItFast()
    self.setSpeed('fast')
    super
  end
end
Riml

    assert_raises(Riml::InvalidSuper) do
      compile(riml)
    end
  end

  test "redefining existing class raises error" do
    riml = <<Riml
class A
end

class A
end
Riml

    assert_raises Riml::ClassRedefinitionError do
      compile(riml)
    end
  end

  test "warns when defining an initalize method in a class with defm instead of def" do
    riml = <<Riml
class Human
  defm initialize(eyeColor)
  end
end
Riml
    expected = compile(riml.sub('defm', 'def'))
    assert_riml_warning do
      assert_equal expected, compile(riml)
    end
  end

  test "can change scope modifier of class" do
    riml = <<Riml
class g:Node
end
Riml

    expected = <<Viml
function! g:NodeConstructor()
  let nodeObj = {}
  return nodeObj
endfunction
Viml
    assert_equal expected, compile(riml)
  end

  test "viml command (source)" do
    riml = "source file.vim"
    assert_equal riml, compile(riml).chomp
  end

  test "viml command (source!)" do
    riml = "source! file.riml.vim"
    assert_equal riml, compile(riml).chomp
  end

  test "echo can take multiple arguments separated by whitespace" do
    riml = 'echo "hello " "world" "!"'
    expected = riml + "\n"
    assert compile(riml)
    assert_equal expected, compile(riml)
  end

  test "function can take one default parameter" do
    riml = <<Riml
def HttpGet(url = 'www.geocities.net')
  return DoHttpGet(url)
end
Riml
    expected = <<Viml
function! s:HttpGet(...)
  let __splat_var_cpy = copy(a:000)
  if !empty(__splat_var_cpy)
    let url = remove(__splat_var_cpy, 0)
  else
    let url = 'www.geocities.net'
  endif
  return s:DoHttpGet(url)
endfunction
Viml

    assert_equal expected, compile(riml)
  end

  test "function can take multiple default parameters" do
    riml = <<Riml
def HttpGet(url = 'www.geocities.net', method='get')
  return DoHttpGet(url, method)
end
Riml
    expected = <<Viml
function! s:HttpGet(...)
  let __splat_var_cpy = copy(a:000)
  if !empty(__splat_var_cpy)
    let url = remove(__splat_var_cpy, 0)
  else
    let url = 'www.geocities.net'
  endif
  if !empty(__splat_var_cpy)
    let method = remove(__splat_var_cpy, 0)
  else
    let method = 'get'
  endif
  return s:DoHttpGet(url, method)
endfunction
Viml
    assert_equal expected, compile(riml)
  end

  test "can't have non-default param after default param" do
    riml = <<Riml
def HttpGet(url = 'www.geocities.net', method)
  return DoHttpGet(url, method)
end
Riml

    assert_raises(Riml::UserArgumentError) do
      compile(riml)
    end
  end

  test "can have a splat literal after default parameters" do
    riml = <<Riml
def HttpGet(url = 'www.geocities.net', method='get', ...)
  return DoHttpGet(url, method)
end
Riml
    expected = <<Viml
function! s:HttpGet(...)
  let __splat_var_cpy = copy(a:000)
  if !empty(__splat_var_cpy)
    let url = remove(__splat_var_cpy, 0)
  else
    let url = 'www.geocities.net'
  endif
  if !empty(__splat_var_cpy)
    let method = remove(__splat_var_cpy, 0)
  else
    let method = 'get'
  endif
  return s:DoHttpGet(url, method)
endfunction
Viml

    assert_equal expected, compile(riml)
  end

  test "can have a *splat after default parameters" do
    riml = <<Riml
def HttpGet(url = 'www.geocities.net', method='get', *options)
  return DoHttpGet(url, method, options)
end
Riml
    expected = <<Viml
function! s:HttpGet(...)
  let __splat_var_cpy = copy(a:000)
  if !empty(__splat_var_cpy)
    let url = remove(__splat_var_cpy, 0)
  else
    let url = 'www.geocities.net'
  endif
  if !empty(__splat_var_cpy)
    let method = remove(__splat_var_cpy, 0)
  else
    let method = 'get'
  endif
  return s:DoHttpGet(url, method, __splat_var_cpy)
endfunction
Viml

    assert_equal expected, compile(riml)
  end

  test "default function param as method call" do
    riml = <<Riml
def HttpGet(url = 'www.geocities.net', method = determineMethod(), *options)
  return DoHttpGet(url, method, options)
end
Riml
    expected = <<Viml
function! s:HttpGet(...)
  let __splat_var_cpy = copy(a:000)
  if !empty(__splat_var_cpy)
    let url = remove(__splat_var_cpy, 0)
  else
    let url = 'www.geocities.net'
  endif
  if !empty(__splat_var_cpy)
    let method = remove(__splat_var_cpy, 0)
  else
    let method = s:determineMethod()
  endif
  return s:DoHttpGet(url, method, __splat_var_cpy)
endfunction
Viml

    assert_equal expected, compile(riml)
  end

  test "nested function scopes are correct" do
    riml = <<Riml
def func(hey)
  echo hey
  def func2(hey2)
    echo hey2
    echo hey " undefined in this function (error)
    for i in expr()
      echo i
      echo hey2
    end
  end
end
Riml
    expected = <<Viml
function! s:func(hey)
  echo a:hey
  function! s:func2(hey2)
    echo a:hey2
    echo hey
    for i in s:expr()
      echo i
      echo a:hey2
    endfor
  endfunction
endfunction
Viml
    assert_equal expected, compile(riml)
  end

    test "curly brace name node in for loop (tripped up compiler)" do
    riml = <<Riml
for i in range(7)
  let repl_{i} = ''
endfor
Riml

    expected = <<Viml
for s:i in range(7)
  let s:repl_{s:i} = ''
endfor
Viml

    assert_equal expected, compile(riml)
  end

  test "nested ifs indent properly" do
    riml = <<Riml
if a
  if b
    echo b2
  elseif c
    if d
      echo d2
    elseif e
      echo f
    else
      echo g
    endif
  else
    echo h
  endif
elseif i
  echo j
else
  echo k
endif
Riml

    expected = <<Viml
if s:a
  if s:b
    echo s:b2
  elseif s:c
    if s:d
      echo s:d2
    elseif s:e
      echo s:f
    else
      echo s:g
    endif
  else
    echo s:h
  endif
elseif s:i
  echo s:j
else
  echo s:k
endif
Viml
    assert_equal expected, compile(riml)
  end

  test "nested trys indent properly" do
    riml = <<Riml
try
  something()
catch /error/
  try
    somethingElse()
  catch /otherError/
    forChristsSake()
  finally
    try
      innerCleanup()
    end
  end
finally
  outerCleanup()
end
Riml
    expected = <<Viml
try
  call s:something()
catch /error/
  try
    call s:somethingElse()
  catch /otherError/
    call s:forChristsSake()
  finally
    try
      call s:innerCleanup()
    endtry
  endtry
finally
  call s:outerCleanup()
endtry
Viml

    assert_equal expected, compile(riml)
  end

  test "curly brace names can start identifiers" do
    riml = <<Riml
let s:{a:namespace}_prototype[name] = s:function('s:' . a:namespace . '_' . name)
Riml
    expected = <<Viml
let s:{a:namespace}_prototype[s:name] = s:function('s:' . a:namespace . '_' . s:name)
Viml
    assert_equal expected, compile(riml)
  end

  test "tripped up compiler" do
    riml = <<Riml
let repo = {'git_dir': dir}
Riml

    expected = <<Viml
let s:repo = {'git_dir': s:dir}
Viml

    assert_equal expected, compile(riml)
  end

  test "concatenation edge case 1: concatenate result of 2 function calls without scope modifiers, can't assume concatenation" do
    # This is either string concatenation of the result of two function
    # calls, or `call1()` returns a dictionary with the `call2()` method on it.
    # The VimL interpreter deals with this by keeping track of types. Riml is
    # forced to GUESS what you want. It makes the assumption that you want
    # to call the method `call2()` of the dictionary which is the result of
    # calling `s:call1()`. NOTE: to unambiguously mean string concatenation,
    # use spaces between the dot. Ex: `call1() . call()`
    riml = <<Riml
res = call1().call2()
Riml

    expected = <<Viml
let s:res = s:call1().call2()
Viml

    assert_equal expected, compile(riml)
  end

  test "concatenation edge case 2: concatenate result of 2 function calls with scope modifiers" do
    # unambiguous string concatenation
    riml = <<Riml
res = s:call1().s:call2()
Riml

    expected = <<Viml
let s:res = s:call1() . s:call2()
Viml

    assert_equal expected, compile(riml)
  end

  test "concatenation edge case 3: function call with dict key can't assume concatenation " do
    # This is either string concatenation or dictionary indexing. The VimL
    # interpreter deals with this ambiguity by keeping track of types.
    # Riml does NOT do this, so assumes that you mean dictionary indexing.
    # NOTE: to unambiguously mean string concatenation, put spaces between the
    # dot. Ex: `res = s:getDict() . someString`
    riml = <<Riml
res = s:getDict().someKey
Riml

    expected = <<Viml
let s:res = s:getDict().someKey
Viml

    assert_equal expected, compile(riml)
  end

  test "concatenation edge case 4: concatenate var or dict with scope modified variable or dict" do
    # unambiguous string concatenation
    riml = <<Riml
res = arg.a:arg
Riml

    expected = <<Viml
let s:res = s:arg . a:arg
Viml

    assert_equal expected, compile(riml)
  end

  test "shadowed argument variable, simple" do
    riml = <<Riml
def func(arg)
  arg = arg
  echo arg
end
Riml

    expected = <<Viml
function! s:func(arg)
  let arg = a:arg
  echo arg
endfunction
Viml

    assert_equal expected, compile(riml)
  end

  test "don't shadow argument when assigning key-value pair to argument variable dictionary (bracket syntax)" do
    riml = <<Riml
def func(arg, idx)
  arg[idx] = 'omg'
  echo arg[idx]
end
Riml

    expected = <<Viml
function! s:func(arg, idx)
  let a:arg[a:idx] = 'omg'
  echo a:arg[a:idx]
endfunction
Viml

    assert_equal expected, compile(riml)
  end

  test "don't shadow argument when assigning key-value pair to argument variable dictionary (dot syntax)" do
    riml = <<Riml
def func(arg)
  arg.msg = 'omg'
  echo arg.msg
end
Riml

    expected = <<Viml
function! s:func(arg)
  let a:arg.msg = 'omg'
  echo a:arg.msg
endfunction
Viml

    assert_equal expected, compile(riml)
  end

  test "shadowed argument variable with dictionary" do
    riml = <<Riml
def func(dict)
  dict = dict
  echo dict.echoMsg
end
Riml

    expected = <<Viml
function! s:func(dict)
  let dict = a:dict
  echo dict.echoMsg
endfunction
Viml

    assert_equal expected, compile(riml)
  end

  test "serialized assignment" do
    riml = 'a = b = c = 1'
    expected = <<Viml
let s:c = 1
let s:b = s:c
let s:a = s:b
Viml

    assert_equal expected, compile(riml)
  end

  test "multi-assignment" do
    riml = 'a = b, b = c'
    expected = <<Viml
let s:a = s:b
let s:b = s:c
Viml
    assert_equal expected, compile(riml)
  end

  # Regression test: there was a bug where the compiler was putting the last
  # two chars on the next line in this situation.
  test "call inside dictionary inside call compiles well" do
    riml = <<Riml
let header = b:NERDTreeRoot.path.str({'format': 'UI', 'truncateTo': winwidth(0)})
Riml

    expected = <<Viml
let s:header = b:NERDTreeRoot.path.str({'format': 'UI', 'truncateTo': winwidth(0)})
Viml

    assert_equal expected, compile(riml)
  end

  test "using 'defm' outside of class gives warning during compilation" do
    riml = <<Riml
defm Mistake()
end
Riml

    expected = <<Viml
function! s:Mistake()
endfunction
Viml

    assert_riml_warning(/should only be used inside classes/) do
      assert_equal expected, compile(riml)
    end
  end

  test "<SID> in function definition" do
    riml = <<Riml
def <SID>Func()
end
Riml

    expected = <<Viml
function! <SID>s:Func()
endfunction
Viml

    assert_equal expected, compile(riml)
  end

  test "warn if <SID> is misspelled or different case in function definition" do
    riml = <<Riml
def <sid>Func()
end
Riml

    expected = <<Viml
function! <SID>s:Func()
endfunction
Viml

    assert_riml_warning do
      assert_equal expected, compile(riml)
    end
  end

  test "Riml.compile can take any object that responds to :read and returns String" do
    obj = Object.new
    def obj.read
      <<Riml
let i = 0
Riml
    end
    expected = "let s:i = 0\n"
    assert_equal expected, Riml.compile(obj, :readable => false)
  end

  # https://github.com/luke-gru/riml/issues/8
  test "passing obj constructor call to function doesn't create spurious newline before ending ')'" do
    riml = <<Riml
class Person
end

def add_person(person)
  echo 'add_person'
end

add_person(new Person())
Riml

    expected = <<Viml
function! s:PersonConstructor()
  let personObj = {}
  return personObj
endfunction
function! s:add_person(person)
  echo 'add_person'
endfunction
call s:add_person(s:PersonConstructor())
Viml
    assert_equal expected, compile(riml)
  end

  test "private methods are transformed to methods that take the obj as a parameter explicitly" do
    riml = <<Riml
class g:Global
  def initialize
    self.priv_data = 'data'
  end

  defm greet
    echo "hi"
    self.priv()
  end

  def priv
    echo self.priv_data
  end
end
Riml

  expected = <<Viml
function! g:GlobalConstructor()
  let globalObj = {}
  let globalObj.priv_data = 'data'
  let globalObj.greet = function('<SNR>' . s:SID() . '_s:Global_greet')
  return globalObj
endfunction
function! s:Global_priv(globalObj)
  echo a:globalObj.priv_data
endfunction
function! <SID>s:Global_greet() dict
  echo "hi"
  call s:Global_priv(self)
endfunction
Viml

    assert_equal expected, compile(riml)
  end

  test "calling private methods from member functions and the initialize method works fine" do
    riml = <<Riml
class ScriptLocal
end

class g:Global < ScriptLocal

  def initialize
    super
    self.priv_data = 'data'
    self.priv()
  end

  defm greet
    echo "hi"
    self.priv()
  end

  def priv
    echo self.priv_data
  end

  def other_priv
    self.priv()
  end
end
Riml

    expected = <<Viml
function! s:ScriptLocalConstructor()
  let scriptLocalObj = {}
  return scriptLocalObj
endfunction
function! g:GlobalConstructor()
  let globalObj = {}
  let scriptLocalObj = s:ScriptLocalConstructor()
  call extend(globalObj, scriptLocalObj)
  let globalObj.priv_data = 'data'
  call s:Global_priv(globalObj)
  let globalObj.greet = function('<SNR>' . s:SID() . '_s:Global_greet')
  return globalObj
endfunction
function! s:Global_priv(globalObj)
  echo a:globalObj.priv_data
endfunction
function! s:Global_other_priv(globalObj)
  call s:Global_priv(a:globalObj)
endfunction
function! <SID>s:Global_greet() dict
  echo "hi"
  call s:Global_priv(self)
endfunction
Viml
    assert_equal expected, compile(riml)
  end

  # issue: https://github.com/luke-gru/riml/issues/10
  test "elseif sets proper scopes for variables/functions" do
    riml = <<Riml
def get_bar()
  my_var = 'foo'

  if my_var == 'a'
    return 'A'
  elseif my_var == 'b'
    return 'B'
  else
    return 'Unknown'
  end
end
Riml

    expected = <<Viml
function! s:get_bar()
  let my_var = 'foo'
  if my_var ==# 'a'
    return 'A'
  elseif my_var ==# 'b'
    return 'B'
  else
    return 'Unknown'
  endif
endfunction
Viml
    assert_equal expected, compile(riml)
  end

  # issue: https://github.com/luke-gru/riml/issues/11
  test "trailing whitespaces after function name or () in function definition doesn't error out" do
    riml = "def hello()        \n\t\t end"

    expected = <<Viml
function! s:hello()
endfunction
Viml
    assert_equal expected, compile(riml)
  end

  test "passing :readable => true to `Riml.compile` outputs 2 <NL> after function definition" do
    riml = <<Riml
def test
end
def test2
end
Riml
    expected = <<Viml
function! s:test()
endfunction

function! s:test2()
endfunction

Viml
    assert_equal expected, Riml.compile(riml, :readable => true)
  end

  # issue: https://github.com/luke-gru/riml/issues/13
  test "super can be in right-side of assignment" do
    riml = <<Riml
class Box
  defm get_color(a, b)
    return 'white'
  end
end

class RedBox < Box
  defm get_color(a, b, c)
    color = super(a, b)
    return color . ' red'
  end
end

red_box = new RedBox()
echo red_box.get_color(1, 2, 3)
Riml

    expected = <<Viml
function! s:BoxConstructor()
  let boxObj = {}
  let boxObj.get_color = function('<SNR>' . s:SID() . '_s:Box_get_color')
  return boxObj
endfunction
function! <SID>s:Box_get_color(a, b) dict
  return 'white'
endfunction
function! s:RedBoxConstructor()
  let redBoxObj = {}
  let boxObj = s:BoxConstructor()
  call extend(redBoxObj, boxObj)
  let redBoxObj.get_color = function('<SNR>' . s:SID() . '_s:RedBox_get_color')
  let redBoxObj.Box_get_color = function('<SNR>' . s:SID() . '_s:Box_get_color')
  return redBoxObj
endfunction
function! <SID>s:RedBox_get_color(a, b, c) dict
  let color = self.Box_get_color(a:a, a:b)
  return color . ' red'
endfunction
let s:red_box = s:RedBoxConstructor()
echo s:red_box.get_color(1, 2, 3)
Viml

    assert_equal expected, compile(riml)
  end

  # issue: https://github.com/luke-gru/riml/issues/15
  test "if block inside unless block" do
    riml = <<Riml
unless 'a' == 'b'
  if 1 == 2
    echo 'nope'
  else
    echo 'yup'
  end
end
Riml

    expected = <<Viml
if !('a' ==# 'b')
  if 1 ==# 2
    echo 'nope'
  else
    echo 'yup'
  endif
endif
Viml

    assert_equal expected, compile(riml)
  end

  # issue: https://github.com/luke-gru/riml/issues/31
  # default param node wasn't being visited by DefaultParamToIfNodeVisitor
  test "default parameter to function inside class" do
    riml = <<Riml
class MyClass
  def bar(foo = {})
  end
end
Riml
    expected = <<Viml
function! s:MyClassConstructor()
  let myClassObj = {}
  return myClassObj
endfunction
function! s:MyClass_bar(myClassObj, ...)
  let __splat_var_cpy = copy(a:000)
  if !empty(__splat_var_cpy)
    let foo = remove(__splat_var_cpy, 0)
  else
    let foo = {}
  endif
endfunction
Viml
    assert_equal expected, compile(riml)
  end

  test "splat in calling context with other arguments" do
    riml = <<Riml
def foo(*args)
  let foo = new Foo('hello', ['lol'], 'omg', *args)
end
Riml
    expected = <<Viml
function! s:foo(...)
  let foo = call('s:FooConstructor', ['hello'] + [['lol']] + ['omg'] + a:000)
endfunction
Viml
  end

  # https://github.com/luke-gru/riml/issues/31
  # more precisely: https://github.com/luke-gru/riml/issues/31#issuecomment-33487578
  test "chained call node after ListOrDictGetNode access (issue #31)" do
    riml = <<Riml
class Foo
  def foo
    foo = [1,2,3]
    foo[0].foo()
  end
end
Riml

    expected = <<Viml
function! s:FooConstructor()
  let fooObj = {}
  return fooObj
endfunction
function! s:Foo_foo(fooObj)
  let foo = [1, 2, 3]
  call foo[0].foo()
endfunction
Viml
    assert_equal expected, compile(riml)
  end

  # https://github.com/luke-gru/riml/issues/31
  # more precisely: https://github.com/luke-gru/riml/issues/31#issuecomment-33499817
  test "transform all references to 'self' in initialize function to `classnameObj`" do
    riml = <<Riml
class Foo
  def initialize
    extend(self, {})
  end
end
Riml

expected = <<Viml
function! s:FooConstructor()
  let fooObj = {}
  call extend(fooObj, {})
  return fooObj
endfunction
Viml

    assert_equal expected, compile(riml)
  end

  test "object instantiation inside call node" do
    riml = <<Riml
class g:ConfigureBufferCommand
end
defm load_commands()
  c = self.container
  r = c.lookup('registry')

  r.add(new g:ConfigureBufferCommand(c))
end
Riml

    expected = <<Viml
function! g:ConfigureBufferCommandConstructor()
  let configureBufferCommandObj = {}
  return configureBufferCommandObj
endfunction
function! s:load_commands()
  let c = self.container
  let r = c.lookup('registry')
  call r.add(g:ConfigureBufferCommandConstructor(c))
endfunction
Viml

    assert_equal expected, compile(riml)
  end

end
end
