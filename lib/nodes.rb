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

class RegexpNode < LiteralNode; end
class ListNode < LiteralNode; end
class DictionaryNode < LiteralNode; end

class TrueNode < LiteralNode
  def initialize() super(true) end
end

class FalseNode < LiteralNode
  def initialize() super(false) end
end

class NilNode < LiteralNode
  def initialize() super(nil) end
end

module NonReturnable
  def omit_return() true end
end

class FinishNode < LiteralNode
  include NonReturnable
  def initialize() super("finish\n") end
end

class BreakNode < LiteralNode
  include NonReturnable
  def initialize() super("break\n") end
end

class ContinueNode < LiteralNode
  include NonReturnable
  def initialize() super("continue\n") end
end

module FullyNameable
  def self.included(base)
    base.class_eval do
      raise "#{base} must define method 'name'" unless method_defined?(:name)
    end
  end

  def full_name
    if respond_to?(:scope_modifier)
      "#{scope_modifier}#{name}"
    elsif respond_to?(:prefix)
      "#{prefix}#{name}"
    end
  end
end

# Node of a method call, can take any of these forms:
#
#   Method()
#   s:Method(argument1, argument2)
class CallNode < Struct.new(:scope_modifier, :name, :arguments)
  include Riml::Constants
  include Visitable
  include FullyNameable

  def builtin_function?
    return false unless name.is_a?(String)
    scope_modifier.nil? and (BUILTIN_FUNCTIONS + BUILTIN_COMMANDS).include?(name)
  end

  def no_parens_necessary?
    return false unless name.is_a?(String)
    scope_modifier.nil? and BUILTIN_COMMANDS.include?(name)
  end
end

# Node of an explicitly called method, can take any of these forms:
#
#   call Method()
#   call s:Method(argument1, argument2)
class ExplicitCallNode < CallNode; end

class OperatorNode < Struct.new(:operator, :operands)
  include Riml::Constants
  include Visitable
end

class BinaryOperatorNode < OperatorNode
  attr_accessor :strict_equals
  def operand1() operands.first end

  def operand2() operands[1] end

  def ignorecase_capable_operator?(operator)
    IGNORECASE_CAPABLE_BINARY_OPERATORS.include?(operator)
  end
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

# let var = 2
# let s:var = 4
class SetVariableNode < Struct.new(:scope_modifier, :name, :value)
  include Visitable
  include FullyNameable
end

# let &compatible = 1
# let @r = ''
# let $HOME = '/home/luke'
class SetSpecialVariableNode < Struct.new(:prefix, :name, :value)
  include Visitable
  include FullyNameable
end

# let [var1, var2] = expression()
class SetVariableNodeList < Struct.new(:list, :expression)
  include Visitable
end

module QuestionVariableExistence
  def self.included(base)
      base.class_eval do
        raise "#{base} must define method 'name'" unless method_defined?(:name)
        alias name_with_question_mark name
        def name_without_question_mark
          if question_existence?
            name_with_question_mark[0...-1]
          else
            name_with_question_mark
          end
        end
        alias name name_without_question_mark
      end

      def question_existence?
        name_with_question_mark[-1] == ??
      end
  end
end

# s:var
# var
class GetVariableNode < Struct.new(:scope_modifier, :name)
  include Visitable
  include FullyNameable
  include QuestionVariableExistence
  attr_accessor :node_type
end


# &autoindent
# @q
class GetSpecialVariableNode < Struct.new(:prefix, :name)
  include Visitable
  include FullyNameable
  attr_accessor :node_type
end

class CurlyBracePart < Struct.new(:value)
  def interpolated?
    GetVariableNode === value || GetSpecialVariableNode === value
  end

  def regular?
    not interpolated?
  end
end
class CurlyBraceVariable < Struct.new(:parts)
  def <<(part)
    parts << part
    self
  end
end
class GetCurlyBraceNameNode < Struct.new(:scope_modifier, :variable)
  include Visitable
end

# Method definition.
class DefNode < Struct.new(:scope_modifier, :name, :parameters, :keyword, :body)
  include Visitable
  include Enumerable
  include Indentable
  include FullyNameable

  def initialize(*args)
    super
    # max number of arguments in viml
    raise ArgumentError,
      "can't have more than 20 parameters for #{full_name}" if
      parameters.size > 20
  end

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

class IfNode < ControlStructure; end
class UnlessNode < ControlStructure; end

class WhileNode < ControlStructure; end
class UntilNode < ControlStructure; end

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

class ElsifNode < ElseNode; end

# for variable in someFunction(1,2,3)
#   echo variable
# end
#
# OR
#
# for variable in [1,2,3]
#   echo variable
# end
#
# type: :list or :call
class ForNode < Struct.new(:variable, :list_expression, :expressions)
  include Visitable
  include Enumerable
  include Indentable

  alias for_variable variable

  def each(&block)
    expressions.each &block
  end
end

class ForNodeCall < ForNode; end
class ForNodeList < ForNode; end

# lines: [5, 6, 8, 9]
# This means the continuation has 4 lines (line.size is 4) and each line
# preserves the amt of whitespace specified as the value in the array.
# Ex: 1st line preserves 5 spaces, 2nd line preserves 6 spaces, etc...
class LineContinuation < Struct.new(:lines)
  include Visitable
  include Enumerable

  def size
    lines.size
  end

  def [](idx)
    lines[idx]
  end

  def each(&block)
    lines.each &block
  end
end

# dict['key']
# dict.key
# dict['key1']['key2']
class DictGetNode < Struct.new(:dict, :keys)
  include Visitable
end

class DictGetBracketNode < DictGetNode; end
class DictGetDotNode < DictGetNode; end

# dict.key = 'val'
# dict.key.key2 = 'val'
class DictSetNode < Struct.new(:dict, :keys, :val)
  include Visitable
end

# list_or_dict[0]
# function()[identifier]
class ListOrDictGetNode < Struct.new(:list_or_dict, :keys)
  include Visitable
  alias list list_or_dict
  alias dict list_or_dict
end

class TryNode < Struct.new(:try_block, :catch_nodes, :ensure_block)
  include Visitable
  include Indentable
end

class CatchNode < Struct.new(:regexp, :block)
  include Visitable
end

class HeredocNode < Struct.new(:pattern, :string_node)
  include Visitable
end
