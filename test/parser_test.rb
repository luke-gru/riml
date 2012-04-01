require_relative 'test_helper'
require 'parser'
require 'compiler'

class BasicParserTest < Riml::TestCase
  def setup
    @parser = Riml::Parser.new
  end

  test "parsing basic method" do
    code = <<-Riml
    def a_method(a, b)
      true
    end
    Riml
    nodes = Nodes.new([
      DefNode.new(nil, "a_method", ['a', 'b'],
        Nodes.new([TrueNode.new]), 2
      )
    ])
    assert_equal nodes, parse(code)
  end

  test "parsing method with if block" do
    code = <<Riml.strip
def b:another_method(a, b)
  if hello
    true
  else
    false
  end
end
Riml
    nodes = Nodes.new([
      DefNode.new('b:', "another_method", ['a', 'b'], Nodes.new(
        [IfNode.new(CallNode.new("hello", []),
                      Nodes.new([TrueNode.new,
                                 ElseNode.new(
                                 Nodes.new([FalseNode.new])
                                )]),
                   4)]#indent
      ), 2)#indent
    ])
    assert_equal nodes, parse(code)
  end
end
