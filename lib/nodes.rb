require File.expand_path('../constants', __FILE__)

module Visitable
  def accept(visitor)
    visitor.visit(self)
  end

  attr_accessor :parent_node, :scope, :force_newline
  alias parent parent_node
  alias parent= parent_node=

  attr_writer :compiled_output
  def compiled_output
    @compiled_output ||= ''
  end

  # catches "descendant_of_#{some_class}?" methods
  # def descendant_of_call_node?
  #   CallNode === self.parent_node
  # end
  DESCENDANT_OF_REGEX = /\Adescendant_of_(.*?)\?/
  def method_missing(method, *args, &blk)
    if method =~ DESCENDANT_OF_REGEX
      parent_node_name = $1.split('_').map(&:capitalize).join
      parent_node = self.class.const_get parent_node_name
      parent_node === self.parent_node
    else
      super
    end
  end
  def respond_to_missing?(method, include_private = false)
    return true if method =~ DESCENDANT_OF_REGEX
    super
  end
end

module Walkable
  include Enumerable

  def each &block
    children.each &block
  end
  alias walk each

  def previous
    idx = index
    return unless idx
    parent.children.fetch(idx - 1)
  end

  def child_previous_to(node)
    idx = children.find_index(node)
    return unless idx
    children.fetch(idx - 1)
  end

  def insert_before(node, new_node)
    idx = children.find_index(node)
    return unless idx
    children.insert(idx-1, new_node)
  end

  def next
    idx = index
    return unless idx
    parent.children.fetch(idx + 1)
  end

  def child_after(node)
    idx = children.find_index(node)
    return unless idx
    children.fetch(idx + 1)
  end

  def insert_after(node, new_node)
    idx = children.find_index(node)
    return unless idx
    children.insert(idx+1, new_node)
  end

  def index
    parent.children.find_index(self)
  end

  def remove
    idx = index
    parent.children.slice!(idx) if idx
  end

  def replace_with(new_node)
    idx = index
    return unless idx
    parent.children.insert(idx, new_node)
    parent.children.slice!(idx+1)
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
  include Walkable

  def <<(node)
    nodes << node
    self
  end

  # forward missing methods to `nodes` array
  def method_missing(method, *args, &block)
    if nodes.respond_to?(method)
      nodes.send(method, *args, &block)
    else
      super
    end
  end

  def respond_to_missing?(method, include_private = false)
    return true if nodes.respond_to?(method)
    super
  end

  def children
    nodes
  end
end

# Literals are static values that have a Ruby representation, eg.: a string, number, list,
# true, false, nil, etc.
class LiteralNode < Struct.new(:value)
  include Visitable
end

class KeywordNode < Struct.new(:value)
  include Visitable
end

class NumberNode < LiteralNode; end

class StringNode < Struct.new(:value, :type) # type: :d or :s for double- or single-quoted
  include Visitable
end

class RegexpNode < LiteralNode; end
class ListNode < LiteralNode
  def self.wrap(value)
    val = Array === value ? value : [value]
    new(val)
  end
end
class DictionaryNode < LiteralNode; end
class ScopeModifierLiteralNode < LiteralNode; end

class TrueNode < LiteralNode
  def initialize() super(true) end
end

class FalseNode < LiteralNode
  def initialize() super(false) end
end

class NilNode < LiteralNode
  def initialize() super(nil) end
end

class NewlineNode < LiteralNode
  def initialize() super("\n") end
end

class ExLiteralNode < LiteralNode
  def initialize(*)
    super
    self.force_newline = true
  end
end

class FinishNode < KeywordNode
  def initialize() super("finish\n") end
end

class BreakNode < KeywordNode
  def initialize() super("break\n") end
end

class ContinueNode < KeywordNode
  def initialize() super("continue\n") end
end


class ReturnNode < Struct.new(:expression)
  include Visitable
  include Walkable

  def children
    [expression]
  end
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
  include Walkable

  def builtin_function?
    return false unless name.is_a?(String)
    scope_modifier.nil? and (BUILTIN_FUNCTIONS + BUILTIN_COMMANDS).include?(name)
  end

  def builtin_command?
    return false unless name.is_a?(String)
    scope_modifier.nil? and BUILTIN_COMMANDS.include?(name)
  end
  alias no_parens_necessary? builtin_command?

  def must_be_explicit_call?
    return false if builtin_command?
    return true if parent.nil?
    return true if Nodes === parent
    false
  end

  def children
    arguments
  end
end

# Node of an explicitly called method, can take any of these forms:
#
#   call Method()
#   call s:Method(argument1, argument2)
class ExplicitCallNode < CallNode; end

class OperatorNode < Struct.new(:operator, :operands)
  include Visitable
  include Walkable

  def children
    operands
  end
end

class BinaryOperatorNode < OperatorNode
  include Riml::Constants

  def operand1() operands[0] end
  def operand1=(val) operands[0] = val end

  def operand2() operands[1] end
  def operand2=(val) operands[1] = val end

  def ignorecase_capable_operator?(operator)
    IGNORECASE_CAPABLE_OPERATORS.include?(operator)
  end
end

# operator = :ternary
# operands = [condition, if_expr, else_expr]
class TernaryOperatorNode < OperatorNode
  def initialize(operands, operator=:ternary)
    super(operator, operands)
  end

  def condition() operands[0] end

  def if_expr() operands[1] end

  def else_expr() operands[2] end
end

# let var = 2
# let s:var = 4
class SetVariableNode < Struct.new(:scope_modifier, :name, :value)
  include Visitable
  include FullyNameable
  include Walkable

  def children
    [value]
  end
end

# let &compatible = 1
# let @r = ''
# let $HOME = '/home/luke'
class SetSpecialVariableNode < Struct.new(:prefix, :name, :value)
  include Visitable
  include FullyNameable
  include Walkable

  def children
    [value]
  end
end

# let [var1, var2] = expression()
class SetVariableNodeList < Struct.new(:list, :expression)
  include Visitable
  include Walkable

  def children
    [list, expression]
  end
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
  end

  def question_existence?
    name_with_question_mark[-1] == ??
  end
end

# s:var
# var
class GetVariableNode < Struct.new(:scope_modifier, :name)
  include Visitable
  include FullyNameable
  include QuestionVariableExistence
end

# &autoindent
# @q
class GetSpecialVariableNode < Struct.new(:prefix, :name)
  include Visitable
  include FullyNameable
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
  include Walkable

  def children
    [variable]
  end
end

class UnletVariableNode < Struct.new(:bang, :variables)
  include Visitable
  include Walkable

  def <<(variable)
    variables << variable
    self
  end

  def children
    variables
  end
end

# Method definition.
class DefNode < Struct.new(:bang, :scope_modifier, :name, :parameters, :keyword, :expressions)
  include Visitable
  include Indentable
  include FullyNameable
  include Walkable

  def initialize(*args)
    super
    # max number of arguments in viml
    if parameters.size > 20
      raise ArgumentError, "can't have more than 20 parameters for #{full_name}"
    end
  end

  SPLAT = lambda {|arg| arg == '...' || arg[0] == "*"}

  # ["arg1", "arg2"}
  def arg_variables
    @arg_variables ||= parameters.reject(&SPLAT)
  end

  # returns the splat argument or nil
  def splat
    @splat ||= begin
      parameters.select(&SPLAT).first
    end
  end

  def keyword
    return super unless name.include?(".")
    "dict"
  end

  def super_node
    expressions.detect {|n| SuperNode === n}
  end

  def children
     [expressions]
  end

  def method_missing(method, *args, &blk)
    if children.respond_to?(method)
      children.send(method, *args &blk)
    else
      super
    end
  end
end

class DefMethodNode < DefNode
  def to_def_node
    DefNode.new(bang, scope_modifier, name, parameters, keyword, expressions)
  end
end

# abstract control structure
class ControlStructure < Struct.new(:condition, :body)
  include Visitable
  include Indentable
  include Walkable

  def children
    [condition, body]
  end
end

class IfNode < ControlStructure; end
class UnlessNode < ControlStructure; end

class WhileNode < ControlStructure; end
class UntilNode < ControlStructure; end

class ElseNode < Struct.new(:expressions)
  include Visitable
  include Walkable
  alias body expressions

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

  def children
    [expressions]
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
class ForNode < Struct.new(:variable, :list_expression, :expressions)
  include Visitable
  include Indentable
  include Walkable

  alias for_variable variable

  def children
    [variable, list_expression, expressions]
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

  def size
    lines.size
  end

  def [](idx)
    lines[idx]
  end
end

class DictGetNode < Struct.new(:dict, :keys)
  include Visitable
  def children
    [dict] + keys
  end
end

# dict['key']
# dict['key1']['key2']
class DictGetBracketNode < DictGetNode; end

# dict.key
# dict.key.key2
class DictGetDotNode < DictGetNode; end

# dict.key = 'val'
# dict.key.key2 = 'val'
class DictSetDotNode < Struct.new(:dict, :keys, :val)
  include Visitable
  def children
    [dict, val]
  end
end

# list_or_dict[0]
# function()[identifier]
class ListOrDictGetNode < Struct.new(:list_or_dict, :keys)
  include Visitable
  alias list list_or_dict
  alias dict list_or_dict
  def children
    [list_or_dict] + keys
  end
end

# dict[key] = val
# list[key] = val
# list[key][key] = val
class ListOrDictSetNode < Struct.new(:list_or_dict_get_node, :val)
  include Visitable
  def children
    [list_or_dict_get_node, val]
  end
end

class TryNode < Struct.new(:try_block, :catch_nodes, :ensure_block)
  include Visitable
  include Indentable
  include Walkable

  def children
    [try_block, catch_nodes, ensure_block]
  end
end

class CatchNode < Struct.new(:regexp, :expressions)
  include Visitable
  include Walkable

  def children
    [expressions]
  end
end

class HeredocNode < Struct.new(:pattern, :string_node)
  include Visitable
  include Walkable

  def children
    [string_node]
  end
end

class ClassDefinitionNode < Struct.new(:name, :superclass_name, :expressions)
  include Visitable
  include Walkable

  def superclass?
    not superclass_name.nil?
  end

  def constructor
    expressions.detect do |n|
      DefNode === n && (n.name == 'initialize' || n.name.match(/Constructor\Z/))
    end
  end
  alias constructor? constructor

  def constructor_name
    "#{name}Constructor"
  end

  def constructor_obj_name
    name[0].downcase + name[1..-1] + "Obj"
  end

  def children
    [expressions]
  end
end

class SuperNode < Struct.new(:arguments, :with_parens)
  include Visitable
  include Walkable

  def use_all_arguments?
    arguments.empty? && !with_parens
  end

  def children
    arguments
  end
end

class ObjectInstantiationNode < Struct.new(:call_node)
  include Visitable
  include Walkable

  def children
    [call_node]
  end
end
