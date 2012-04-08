# Collection of nodes each one representing an expression.

module Visitable
  def accept(visitor)
    visitor.visit(self)
  end

  attr_accessor :parent_node
  attr_writer :compiled_output
  def compiled_output
    @compiled_output ||= ''
  end

end

class Nodes < Struct.new(:nodes)
  include Visitable
  include Enumerable
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

class ScopeModifierNode < LiteralNode
  def initialize(modifier)
    super
  end
end

# Node of a method call or local variable access, can take any of these forms:
#
#   method # this form can also be a local variable
#   method(argument1, argument2)
#
class CallNode < Struct.new(:method, :arguments)
  include Visitable
end

# Retrieving the value of a constant.
class GetConstantNode < Struct.new(:name)
  include Visitable
end

# Setting the value of a constant.
class SetConstantNode < Struct.new(:name, :value)
  include Visitable
end

# Setting the value of a local variable.
class SetVariableNode < Struct.new(:scope_modifier, :name, :value)
  include Visitable
end

# Method definition.
class DefNode < Struct.new(:scope_modifier, :name, :params, :body, :indent)
  include Visitable
  include Enumerable
  def each(&block)
    body.each &block
  end
end

# "if" control structure. Look at this node if you want to implement other control
# structures like while, for, loop, etc.
class IfNode < Struct.new(:condition, :body)
  include Visitable
  include Enumerable
  def each(&block)
    body.each &block
  end
end

class ElseNode < Struct.new(:expressions)
  include Visitable
  include Enumerable
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
