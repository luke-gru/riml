require File.expand_path('../test_helper', __FILE__)

class BasicCompilerTest < Riml::TestCase

  test "basic function compiles" do
    riml = <<Riml
def a_method(a, b)
  return true
end
Riml

    nodes = Nodes.new([
      DefNode.new('!', nil, "a_method", ['a', 'b'], nil,
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
      DefNode.new('!', 'b:', "another_method", ['a', 'b'], nil, Nodes.new([
        IfNode.new(CallNode.new(nil, "hello", []), Nodes.new([
          FalseNode.new, ElseNode.new(Nodes.new([TrueNode.new]))])),
        ExplicitCallNode.new(nil, "SomeFunction", [])
        ])
      )
    ])

    expected = <<Viml
function! b:another_method(a, b)
  if hello()
    0
  else
    1
  endif
  call SomeFunction()
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

  test "setting variable to nil frees its memory" do
    riml = "b:a = nil"
    expected = "unlet! b:a"

    assert_equal expected, compile(riml).chomp
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

  test "list unpack in let" do
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

  test "for var in list block" do
    riml = <<Riml
for var in [1, 2, 3]
  echo var
endfor
echo "done"
Riml
    expected = riml
    assert_equal expected, compile(riml).chomp
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
if &hello ==# "omg"
  echo &hello
endif
echo "hi"
Viml
    assert_equal expected, compile(riml)
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

    expected = %{let s:heredoc = "omg this is a heredoc\n"}

    assert_equal expected, compile(riml).chomp
  end

  test "heredoc string with interpolation" do
    riml = '
heredoc = <<EOS
Hello there, #{name}, how are you?
EOS
'.strip

    expected = %{let s:heredoc = "Hello there, " . s:name . ", how are you?\n"}

    assert_equal expected, compile(riml).chomp
  end

  test "heredoc string with more than one interpolated expression" do
    riml = '
lineFromMovie = <<EOS
Holy #{loudExpletive()} it\'s freaking #{superhero}!
EOS
'.strip

    expected = %{let s:lineFromMovie = "Holy " . s:loudExpletive() . " it's freaking " . s:superhero . "!\n"}

    assert_equal expected, compile(riml).chomp
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

  test "list sublists" do
    riml = <<Riml
let myList = otherList[0:-1]
Riml

    expected = <<Viml
let s:myList = s:otherList[0 : -1]
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
function! g:MyClassConstructor(arg1, arg2, ...)
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
function! g:MyClassConstructor(arg1, arg2, ...)
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
function! g:MyClassConstructor(arg1, arg2, ...)
  let myClassObj = {}
  function! myClassObj.getData() dict
    return self.data
  endfunction
  function! myClassObj.getOtherData() dict
    return self.otherData
  endfunction
  return myClassObj
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
function! g:TranslationConstructor(input)
  let translationObj = {}
  let translationObj.input = a:input
  return translationObj
endfunction
function! g:FrenchToEnglishTranslationConstructor(input)
  let frenchToEnglishTranslationObj = {}
  let translationObj = g:TranslationConstructor(a:input)
  call extend(frenchToEnglishTranslationObj, translationObj)
  function! frenchToEnglishTranslationObj.translate() dict
    if self.input ==# "Bonjour!"
      echo "Hello!"
    else
      echo "Sorry, I don't know that word."
    endif
  endfunction
  return frenchToEnglishTranslationObj
endfunction
let s:translation = g:FrenchToEnglishTranslationConstructor("Bonjour!")
call s:translation.translate()
Viml

    assert_equal expected, compile(riml)
  end

  test "super with parens in initialize method" do
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
function! g:CarConstructor(make, model, color)
  let carObj = {}
  let carObj.make = a:make
  let carObj.model = a:model
  let carObj.color = a:color
  return carObj
endfunction
function! g:HotRodConstructor(make, model, color, topSpeed)
  let hotRodObj = {}
  let hotRodObj.topSpeed = a:topSpeed
  let carObj = g:CarConstructor(a:make, a:model, a:color)
  call extend(hotRodObj, carObj)
  function! hotRodObj.drive() dict
    if self.topSpeed ># 140
      echo "Ahhhhhhh!"
    else
      echo "Nice"
    endif
  endfunction
  return hotRodObj
endfunction
let s:newCar = g:HotRodConstructor("chevy", "mustang", "red", 160)
call s:newCar.drive()
Viml
    assert_equal expected, compile(riml)
  end

  test "super without parens passes all arguments" do
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
    self.other = other
  end
end
Riml

    expected = <<Viml
function! g:AConstructor(foo, bar)
  let aObj = {}
  let aObj.foo = a:foo
  let aObj.bar = a:bar
  return aObj
endfunction
function! g:BConstructor(foo, bar)
  let bObj = {}
  let aObj = g:AConstructor(a:foo, a:bar)
  call extend(bObj, aObj)
  let bObj.other = other
  return bObj
endfunction
Viml

    assert_equal expected, compile(riml)
  end

  test "implicit super works when inside function that's given a splat parameter" do
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
function! g:AConstructor(foo, ...)
  let aObj = {}
  let aObj.foo = a:foo
  let aObj.options = a:000
  return aObj
endfunction
function! g:BConstructor(foo, ...)
  let bObj = {}
  let bObj.other = calculateOther()
  let aObj = g:AConstructor(a:foo, a:000)
  call extend(bObj, aObj)
  return bObj
endfunction
Viml

    assert_equal expected, compile(riml)
  end
end
