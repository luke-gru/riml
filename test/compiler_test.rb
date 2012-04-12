require File.expand_path('../test_helper', __FILE__)

class BasicCompilerTest < Riml::TestCase

  def setup
    global_variables.clear
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
    expected = 'unlet! b:a' + "\n"

    assert_equal expected, compile(riml)
    assert_equal 1, global_variables.count
  end

  test "unless expression" do
    riml = <<Riml
unless shy()
  echo("hi");
end
Riml

    expected = <<Viml
if (!shy())
  echo("hi")
endif
Viml

    assert_equal expected, compile(riml)
    assert_equal 0, global_variables.count
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
    assert_equal 1, global_variables.count
  end

  test "interpolation in double-quoted strings" do
  riml1 = '"found #{n} words"'
  expected1 = '"found " . s:n . " words"'

  riml2 = '"#{n} words were found"'
  expected2 = 's:n . " words were found"'

  assert_equal expected1, compile(riml1)
  assert_equal expected2, compile(riml2)
  end

  test "functions can take expressions" do
    riml = 'echo("found #{n} words")'
    expected = 'echo("found " . s:n . " words")' + "\n"

    assert_equal expected, compile(riml)
  end

  test "chaining method calls" do
    riml = 'n = n + len(split(getline(lnum)))'
    expected = 'let s:n = s:n + len(split(getline(s:lnum)))' + "\n"

    assert_equal expected, compile(riml)
  end

  # TODO: get rid of semicolon annoyance
  test "function can take range when given parens" do
    riml = <<Riml
def My_function(a,b) range
;
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
if g:a?
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
end
