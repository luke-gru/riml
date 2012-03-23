require_relative 'test_helper'
require 'parser'
require 'compiler'

class BasicParserTest < ActiveSupport::TestCase
  def setup
    @parser = Riml::Parser.new
  end

  def parse(code)
    @parser.parse(code)
  end

  test "basic parsing works" do
    code = <<-Riml
    def a_method(a, b)
      true
    end
    Riml
    nodes = Nodes.new([
      DefNode.new("a_method", ['a', 'b'],
        Nodes.new([TrueNode.new])
      )
    ])
    assert_equal nodes, parse(code)
  end
end
