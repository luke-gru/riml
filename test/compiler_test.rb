require_relative 'test_helper'
require 'compiler'

class BasicCompilerTest < Riml::TestCase
  def setup
    @compiler = Riml::Compiler.new
  end

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
    expect = <<Riml
function s:a_method(a, b)
  return 1
endfunction
Riml
    assert_equal expect, compile(nodes)
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
    expect = <<Riml
function b:another_method(a, b)
  if (hello())
    return 0
  else
    return 1
  endif
endfunction
Riml
    assert_equal expect, compile(nodes)
  end

  test "" do
  end
end
