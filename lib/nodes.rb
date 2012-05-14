require File.expand_path('../constants', __FILE__)

module Scopable
  attr_accessor :scope
end

module Visitable
  include Scopable

  def accept(visitor)
    visitor.visit(self)
  end

  attr_accessor :parent_node
  attr_writer :compiled_output
  def compiled_output
    @compiled_output ||= ''
  end

  # catches "descendant_of_#{some_class}?" methods
  # def descendant_of_call_node?
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

module Indentable
  def indent
    @indent ||= " " * 2
  end
end

# Collection of nodes each one representing an expression.
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

# Literals are static values that have a Ruby representation, eg.: a string, number, list,
# true, false, nil, etc.
class LiteralNode < Struct.new(:value)
  include Visitable

  attr_accessor :explicit_return
end

class NumberNode < LiteralNode; end
class StringNode < Struct.new(:value, :type) # type: :d or :s for double- or single-quoted
  include Visitable

  attr_accessor :explicit_return
end

class ListNode < LiteralNode; end
class DictionaryNode < LiteralNode; end

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

class FinishNode < LiteralNode
  def initialize
    super("finish\n")
  end
end

# Node of a method call, can take any of these forms:
#
#   method()
#   method(argument1, argument2)
class CallNode < Struct.new(:scope_modifier, :name, :arguments)
  include Riml::Constants
  include Visitable

  #def builtin_range?
  #  name == "range" and scope_modifier.nil?
  #end
  def method_missing(method, *args, &blk)
    if method.to_s =~ /\Abuiltin_(.*?)\?\Z/
      name == $1 and scope_modifier.nil?
    else
      super
    end
  end

  def no_parens_necessary?
    VIML_FUNC_NO_PARENS_NECESSARY.include?(name) and scope_modifier.nil?
  end
end

# Node of an explicitly called method, can take any of these forms:
#
#   call method()
#   call method(argument1, argument2)
class ExplicitCallNode < CallNode
end

class OperatorNode < Struct.new(:operator, :operands)
  include Visitable
end

class BinaryOperatorNode < OperatorNode
  def operand1() operands.first end

  def operand2() operands[1] end
end

# operator = :ternary
# operands = [condition, if_expr, else_expr]
class TernaryOperatorNode < OperatorNode
  def initialize(operands, operator=:ternary)
    super(operator, operands)
  end

  def condition() operands.first end

  def if_expr() operands[1] end

  def else_expr() operands[2] end
end

class GetConstantNode < Struct.new(:name)
  include Visitable
end

class SetConstantNode < Struct.new(:name, :value)
  include Visitable
end

class SetVariableNode < Struct.new(:scope_modifier, :name, :value)
  include Visitable
end

# [a, b] = expression()
class SetVariableNodeList < Struct.new(:list, :expression)
  include Visitable
end

class GetVariableNode < Struct.new(:scope_modifier, :name)
  include Visitable
  attr_accessor :node_type

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
  include Indentable

  SPLAT = lambda {|arg| arg == '...' || arg[0] == "*"}

  def local_scope?
    true
  end

  def scoped_variables
    @scoped_variables ||= {}
  end

  # {"a:arg1" => :Argument0, "a:arg2" => :Argument1}
  def arg_variables
    @arg_variables ||=
      Hash[parameters.delete_if(&SPLAT).map.with_index {|p, i| ["a:#{p}", :"Argument#{i}"] }]
  end

  # returns the splat argument or nil
  def splat
    @splat ||= begin
      parameters.select(&SPLAT).first
    end
  end

  def each(&block)
    body.each &block
  end
end

# command? -nargs=1 Correct :call s:Add(<q-args>, 0)
class CommandNode < Struct.new(:command, :nargs, :name, :body)
end

# abstract control structure
class ControlStructure < Struct.new(:condition, :body)
  include Visitable
  include Enumerable
  include Indentable

  def each(&block)
    body.each &block
  end
end

class IfNode < ControlStructure
end

class UnlessNode < ControlStructure
end

class WhileNode < ControlStructure
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

class ElsifNode < ElseNode
end

# for variable in someFunction(1,2,3)
#   echo variable
# end
class ForNode < Struct.new(:variable, :call, :expressions)
  include Visitable
  include Enumerable
  include Indentable

  alias for_variable variable

  def each(&block)
    expressions.each &block
  end
end
