require File.expand_path('../test_helper', __FILE__)

class BasicParserTest < Riml::TestCase

  test "parsing basic method" do
    code = <<-Viml
    def a_method(a, b)
      true
    end
    Viml
    expected = Nodes.new([
      DefNode.new(nil, "a_method", ['a', 'b'],
        Nodes.new([TrueNode.new]), 2
      )
    ])
    assert_equal expected, parse(code)
  end

  test "parsing method with if block" do
    code = <<Viml
def b:another_method(a, b)
  if hello
    true
  else
    false
  end
end
Viml
    expected = Nodes.new([
      DefNode.new('b:', "another_method", ['a', 'b'], Nodes.new(
        [IfNode.new(CallNode.new("hello", []),
                      Nodes.new([TrueNode.new,
                                 ElseNode.new(
                                 Nodes.new([FalseNode.new])
                                )])
                   )]
      ), 2) #indent
    ])
    assert_equal expected, parse(code)
  end

  test "parsing a ruby-like 'if this then that end' expression" do
    code = <<-Riml
    if b then a = 2 end
    Riml
    expected = Nodes.new([
      IfNode.new(
        CallNode.new('b', []),
        Nodes.new(
          [SetVariableNode.new(nil, 'a', NumberNode.new(2))]
        )
      )
    ])
    assert_equal expected, parse(code)
  end

  # TODO: fix scope_modifier and parens in if expressions
  test "parsing an unless expression" do
    riml = <<Riml
unless (salutation)
  echo("hi");
end
Riml
    expected = Nodes.new([
      UnlessNode.new(
        CallNode.new('salutation', []),
        Nodes.new(
          [ CallNode.new('echo', [StringNode.new('hi')]) ]
        )
      )
    ])

    assert_equal expected, parse(riml)
  end
end
