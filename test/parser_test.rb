require_relative 'test_helper'

class BasicParserTest < Riml::TestCase

  test "parsing basic method" do
    code = <<-Riml
    def a_method(a, b)
      true
    end
    Riml
    expected = Nodes.new([
      DefNode.new(nil, "a_method", ['a', 'b'],
        Nodes.new([TrueNode.new]), 2
      )
    ])
    assert_equal expected, parse(code)
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
    expected = Nodes.new([
      DefNode.new('b:', "another_method", ['a', 'b'], Nodes.new(
        [IfNode.new(CallNode.new("hello", []),
                      Nodes.new([TrueNode.new,
                                 ElseNode.new(
                                 Nodes.new([FalseNode.new])
                                )]),
                   4)]#indent
      ), 2)#indent
    ])
    assert_equal expected, parse(code)
  end

  test "parsing a ruby-like 'if this then that end' expression" do
    code = <<-Riml.strip
    if b then a = 2 end
    Riml
    expected = Nodes.new([
      IfNode.new(CallNode.new('b', []), SetVariableNode.new(nil, 'a', NumberNode.new(2)),
        nil #indent
      )
    ])
    assert_equal expected, parse(code)
  end
end
