require_relative 'test_helper'
require 'compiler'

class BasicCompilerTest < ActiveSupport::TestCase
  def setup
    @compiler = Riml::Compiler.new
  end

  def compile(code)
    @compiler.compile(code)
  end

  test "basic compiling works" do
=begin
    def a_method(a, b)
      true
    end
=end
    nodes = Nodes.new([
      DefNode.new("a_method", ['a', 'b'],
        Nodes.new([TrueNode.new])
      )
    ])
    assert_equal "function a_method(a, b)\n", compile(nodes)
  end
end
