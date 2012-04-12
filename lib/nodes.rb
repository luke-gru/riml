# Collection of nodes each one representing an expression.

# global methods
def debug?
  not ENV["DEBUG"].nil?
end

def global_variables
  @@global_variables ||= []
end

module Visitable
  def accept(visitor)
    visitor.visit(self)
  end

  attr_accessor :parent_node
  attr_writer :compiled_output
  def compiled_output
    @compiled_output ||= ''
  end

  # catches "descendant_of_#{some_node}?" methods
  # def descendant_of_callnode?
  #   CallNode === self.parent_node
  # end
  def method_missing(method, *args, &blk)
    if method.to_s =~ /descendant_of_(.*?)\?/
      parent_node_name = $1.split('_').map(&:capitalize).join
      parent_node = self.class.const_get parent_node_name
      parent_node === self.parent_node
    else
      super
    end
  end
end


class Nodes < Struct.new(:nodes)
  include Visitable
  include Enumerable

  attr_accessor :scope

  def <<(node)
    nodes << node
    self
  end

  def pop
    nodes.pop
  end

  def last
    nodes.last
  end

  def each(&block)
    nodes.each &block
  end
end

# Literals are static values that have a Ruby representation, eg.: a string, a number,
# true, false, nil, etc.
class LiteralNode < Struct.new(:value)
  include Visitable

  attr_accessor :scope
  attr_accessor :explicit_return
end

class NumberNode < LiteralNode; end
class StringNode < LiteralNode; end

class TrueNode < LiteralNode
  def initialize
    super(true)
  end
end

class FalseNode < LiteralNode
  def initialize
    super(false)
  end
end

class NilNode < LiteralNode
  def initialize
    super(nil)
  end
end

class NewlineNode < LiteralNode
  def initialize
    super("\n")
  end
end

# to prepend next to a node that
# needs explicit returning
class ReturnNode < LiteralNode
  def initialize
    super("return")
  end
end

# Node of a method call or local variable access, can take any of these forms:
#
#   variable
#   method()
#   method(argument1, argument2)
#
class CallNode < Struct.new(:scope_modifier, :name, :arguments)
  include Visitable

  attr_accessor :scope
end

class OperatorNode < Struct.new(:operator, :operands)
  include Visitable

  attr_accessor :scope
end

class BinaryOperatorNode < OperatorNode
  def operand1
    operands.first
  end

  def operand2
    operands[1]
  end
end

# Retrieving the value of a constant.
class GetConstantNode < Struct.new(:name)
  include Visitable

  attr_accessor :scope
end

# Setting the value of a constant.
class SetConstantNode < Struct.new(:name, :value)
  include Visitable

  attr_accessor :scope
end

# Setting the value of a local variable.
class SetVariableNode < Struct.new(:scope_modifier, :name, :value)
  include Visitable

  attr_accessor :scope
end

class GetVariableNode < Struct.new(:scope_modifier, :name)
  include Visitable

  attr_accessor :scope

  alias name_with_question_mark name
  def name_without_question_mark
    if question_existence?
      name_with_question_mark[0...-1]
    else
      name_with_question_mark
    end
  end
  alias name name_without_question_mark

  def question_existence?
    name_with_question_mark[-1] == ??
  end

end

# Method definition.
class DefNode < Struct.new(:scope_modifier, :name, :parameters, :keyword, :body, :indent)
  include Visitable
  include Enumerable

  attr_accessor :scope

  def local?
    true
  end

  def scoped_variables
    @scoped_variables ||= []
  end

  def arg_variables
    @arg_variables ||= parameters
  end

  def each(&block)
    body.each &block
  end
end

# "if" control structure. Look at this node if you want to implement other control
# structures like while, for, loop, etc.
class IfNode < Struct.new(:condition, :body)
  include Visitable
  include Enumerable

  attr_accessor :scope

  def each(&block)
    body.each &block
  end
end

class UnlessNode < IfNode
  def unless
    true
  end
end

class ElseNode < Struct.new(:expressions)
  include Visitable
  include Enumerable

  attr_accessor :scope

  def each(&block)
    expressions.each &block
  end

  def <<(expr)
    expressions << expr
    self
  end

  def pop
    expressions.pop
  end

  def last
    expressions.last
  end
end
