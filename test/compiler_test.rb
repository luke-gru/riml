require File.expand_path('../test_helper', __FILE__)

class BasicCompilerTest < Riml::TestCase

  def setup
    global_variables.clear
  end

  test "basic function compiles" do
=begin
    def a_method(a, b)
      true
    end
=end
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
  end

  test "branching function compiles and returns on all branches" do
=begin
    def b:another_method(a, b)
      if (hello)
        false
      else
        true
      end
    end
=end

    nodes = Nodes.new([
      DefNode.new('b:', "another_method", ['a', 'b'], nil, Nodes.new(
        [IfNode.new(CallNode.new(nil, "hello", []), Nodes.new([FalseNode.new, ElseNode.new(Nodes.new([TrueNode.new]))]))]
      ),2)
    ])

    # NOTE: change below so 'hello' doesn't take parens
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
  end

  test "ruby-like if this then that end expression" do

    riml = "if b() then a = 2 end\n"
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
    riml = "b:a = nil\n"
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

  # TODO: need to test by prefixing everything with echo
  test "interpolation in double-quoted strings" do
  riml = '"found #{n} words"'
  expected = '"found " . s:n . "words"'

  assert_equal expected, compile(riml)
  end

  test "functions can take expressions" do
    riml = 'echo("found #{n} words")'
    expected = 'echo("found " . s:n . "words")' + "\n"

    assert_equal expected, compile(riml)
  end
end
