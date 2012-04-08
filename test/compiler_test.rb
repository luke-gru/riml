require_relative 'test_helper'

class BasicCompilerTest < Riml::TestCase

  test "basic function compiles" do
=begin
    def a_method(a, b)
      true
    end
=end
    nodes = Nodes.new([
      DefNode.new(nil, "a_method", ['a', 'b'],
        Nodes.new([TrueNode.new]), 2
      )
    ])
    expected = <<Viml
function s:a_method(a, b)
  return 1
endfunction
Viml
    assert_equal expected, compile(nodes)
  end

  test "branching function compiles and returns on all branches" do
=begin
    def another_method(a, b)
      if (hello)
        false
      else
        true
      end
    end
=end
    nodes = Nodes.new([
      DefNode.new('b:', "another_method", ['a', 'b'], Nodes.new(
        [IfNode.new(CallNode.new("hello", []), Nodes.new([FalseNode.new, ElseNode.new(Nodes.new([TrueNode.new]))]), 4)]
      ),2)
    ])
    expected = <<Viml
function b:another_method(a, b)
  if (hello())
    return 0
  else
    return 1
  endif
endfunction
Viml
    assert_equal expected, compile(nodes)
  end

  # no explicit returns on one-line 'if-then' statements
  test "ruby-like if this then that end expression" do

    riml = "if b then a = 2 end"
    nodes = Nodes.new([
      IfNode.new(
        CallNode.new('b', []),
        Nodes.new(
          [SetVariableNode.new(nil, 'a', NumberNode.new(2))]
        ),
        2 #indent
      )
    ])

  expected = <<Viml
if (b())
  s:a = 2
endif
Viml
    assert_equal expected, compile(nodes)
  end
end
