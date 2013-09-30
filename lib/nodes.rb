require File.expand_path('../constants', __FILE__)
require File.expand_path('../errors', __FILE__)
require 'set'

module Riml
  module Visitable
    def accept(visitor)
      visitor.visit(self)
    end

    attr_accessor :parent_node, :scope, :force_newline, :parser_info
    alias parent parent_node
    alias parent= parent_node=

    attr_writer :compiled_output
    def compiled_output
      @compiled_output ||= ''
    end

    def location_info
      n = self
      while n != nil && !n.parser_info
        n = n.parent
      end
      if n.nil?
        return '<unknown>'
      end
      filename = parser_info[:filename] || Constants::COMPILED_STRING_LOCATION
      "#{filename}:#{parser_info[:lineno]}"
    end

    # catches "descendant_of_#{some_class}?" methods
    # def descendant_of_call_node?
    #   CallNode === self.parent_node
    # end
    DESCENDANT_OF_REGEX = /\Adescendant_of_(.*?)\?/
    def method_missing(method, *args, &blk)
      if method =~ DESCENDANT_OF_REGEX
        parent_node_name = $1.split('_').map(&:capitalize).join
        parent_node = Riml.const_get parent_node_name
        parent_node === self.parent_node
      else
        super
      end
    end
    def respond_to?(method, include_private = false)
      super || method =~ DESCENDANT_OF_REGEX
    end
  end

  module Walkable
    include Enumerable

    def each(&block)
      children.each(&block)
    end
    alias walk each

    def previous
      idx = index_by_member
      if idx && parent.members[idx - 1]
        attr = parent.members[idx - 1]
        return send(attr)
      else
        idx = index_by_children
        return unless idx
        parent.children.fetch(idx - 1)
      end
    end

    def child_previous_to(node)
      node.previous
    end

    def insert_before(node, new_node)
      idx = children.find_index(node)
      return unless idx
      children.insert(idx - 1, new_node)
    end

    def next
      idx = index_by_member
      if idx && parent.members[idx + 1]
        attr = parent.members[idx + 1]
        return parent.send(attr)
      else
        idx = index_by_children
        return unless idx
        parent.children.fetch(idx + 1)
      end
    end

    def child_after(node)
      node.next
    end

    def insert_after(node, new_node)
      idx = children.find_index(node)
      return unless idx
      children.insert(idx + 1, new_node)
    end

    def index_by_member
      attrs = parent.members
      attrs.each_with_index do |attr, i|
        if parent.send(attr) == self
          return i
        end
      end
      nil
    end

    def index_by_children
      parent.children.find_index(self)
    end

    def remove
      idx = index_by_member
      if idx
        attr = parent.members[idx]
        parent.send("#{attr}=", nil)
      else
        idx = index_by_children
        parent.children.slice!(idx) if idx
      end
    end

    def replace_with(new_node)
      idx = index_by_member
      if idx
        attr = parent.members[idx]
        new_node.parent = parent
        parent.send("#{attr}=", new_node)
      else
        idx = index_by_children
        return unless idx
        new_node.parent = parent
        parent.children.insert(idx, new_node)
        parent.children.slice!(idx + 1)
      end
    end
  end

  module Indentable
    def indent
      @indent ||= ' ' * 2
    end
    def indented?
      indent.size > 0
    end
    def outdent
      size = indent.size
      return '' unless size > 0
      ' ' * (size - 2)
    end
  end

  module NotNestedUnder
    def non_nested?(klass = not_nested_under_class)
      n = self
      while (n = n.parent) != nil
        return false if n.is_a?(klass)
      end
      true
    end

    # override if applicable
    def not_nested_under_class
      self.class
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

    def [](idx)
      nodes[idx]
    end

    def concat(list_of_nodes)
      nodes.concat(list_of_nodes)
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

    def respond_to?(method, include_private = false)
      super || nodes.respond_to?(method, include_private)
    end

    def children
      nodes
    end
  end

  class SublistNode < Nodes; end

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

  class StringLiteralConcatNode < Struct.new(:string_nodes)
    include Visitable
    include Walkable

    def initialize(*string_nodes)
      super(string_nodes)
    end
    alias nodes string_nodes

    def children
      string_nodes
    end
  end

  class RegexpNode < LiteralNode; end

  class ListNode < LiteralNode
    include Walkable
    def self.wrap(value)
      val = Array === value ? value : [value]
      new(val)
    end

    def children
      value
    end
  end

  class ListUnpackNode < ListNode
    def rest
      value.last
    end
  end

  class DictionaryNode < LiteralNode
    include Walkable

    def children
      value.to_a.compact.inject([], :concat)
    end
  end

  class ScopeModifierLiteralNode < LiteralNode; end

  class TrueNode < LiteralNode
    def initialize() super(true) end
  end

  class FalseNode < LiteralNode
    def initialize() super(false) end
  end

  class ExLiteralNode < LiteralNode
    def initialize(*)
      super
      self.force_newline = true
    end
  end

  class SIDNode < LiteralNode
    def initialize(ident = 'SID')
      Riml.warn("expected #{ident} to be SID") unless ident == 'SID'
      super('<SID>')
    end
    alias to_s value
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

  class WrapInParensNode < Struct.new(:expression)
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

    ALL_BUILTIN_FUNCTIONS = BUILTIN_FUNCTIONS + BUILTIN_COMMANDS
    ALL_BUILTIN_COMMANDS  = BUILTIN_COMMANDS  + RIML_COMMANDS + VIML_COMMANDS

    def initialize(scope_modifier, name, arguments)
      super
      remove_parens_wrapper if builtin_command?
    end

    # TODO: find way to remove this hack
    def remove_parens_wrapper
      return unless WrapInParensNode === arguments.first
      arguments[0] = arguments[0].expression
    end

    def builtin_function?
      return false unless name.is_a?(String)
      scope_modifier.nil? and ALL_BUILTIN_FUNCTIONS.include?(name)
    end

    def builtin_command?
      return false unless name.is_a?(String)
      scope_modifier.nil? and ALL_BUILTIN_COMMANDS.include?(name)
    end

    def must_be_explicit_call?
      return false if builtin_command?
      return true  if parent.instance_of?(Nodes)
      false
    end

    def autoload?
      name.include?('#')
    end

    def children
      if name.is_a?(String)
        arguments
      else
        [name] + arguments
      end
    end
  end

  # Node of an explicitly called method, can take any of these forms:
  #
  #   call Method()
  #   call s:Method(argument1, argument2)
  class ExplicitCallNode < CallNode; end
  class RimlCommandNode  < CallNode

    def initialize(*)
      super
      if arguments.empty? || !arguments.all? { |arg| arg.is_a?(StringNode) }
        raise Riml::UserArgumentError, "#{name.inspect} error: must pass string(s) (name of file(s))"
      end
    end

    # yields full file path for each existing file found in Riml.source_path
    def each_existing_file!
      files = {}
      arguments.map(&:value).each do |file|
        if base_path = paths.detect do |path|
             full = File.join(path, file)
             File.exists?(full)
           end
          files[file] = File.join(base_path, file)
        else
          raise Riml::FileNotFound, "#{file.inspect} could not be found in " \
            "Riml.#{name.sub('riml_', '')}_path (#{paths.join(':').inspect})"
        end
      end
      return files.values unless block_given?
      # all files exist
      files.each do |basename, full_path|
        begin
          yield basename, full_path
        rescue Riml::IncludeFileLoop, Riml::SourceFileLoop
          arguments.delete_if { |arg| arg.value == basename }
        end
      end
    end

    def paths
      if name == 'riml_include'
        Riml.include_path
      else
        Riml.source_path
      end
    end
  end

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

  class UnaryOperatorNode < OperatorNode
    def initialize(operator, operands)
      len = operands.length
      unless len == 1
        raise ArgumentError, "unary operator must have 1 operand, has #{len}"
      end
      super
    end
    def operand
      operands.first
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
  class AssignNode < Struct.new(:operator, :lhs, :rhs)
    include Visitable
    include Walkable

    def children
      [lhs, rhs]
    end
  end

  class MultiAssignNode < Struct.new(:assigns)
    include Visitable
    include Walkable

    def children
      assigns
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

  class GetCurlyBraceNameNode < Struct.new(:scope_modifier, :variable)
    include Visitable
    include Walkable

    def children
      [variable]
    end
  end

  class CurlyBraceVariable < Struct.new(:parts)
    include Visitable
    include Walkable

    def <<(part)
      parts << part
      self
    end

    def children
      parts
    end
  end

  class CurlyBracePart < Struct.new(:value)
    include Visitable
    include Walkable

    def interpolated?
      GetVariableNode === value || GetSpecialVariableNode === value ||
        CallNode === value || nested?
    end

    def nested?
      value.is_a?(Array) && value.detect {|part| part.is_a?(CurlyBracePart)}
    end

    def children
      if !interpolated?
        []
      elsif nested?
        value
      else
        [value]
      end
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
  class DefNode < Struct.new(:bang, :sid, :scope_modifier, :name, :parameters, :keywords, :expressions)
    include Visitable
    include Indentable
    include FullyNameable
    include Walkable

    attr_accessor :private_function

    def initialize(*args)
      super
      # max number of arguments in viml
      if parameters.reject(&DEFAULT_PARAMS).size > 20
        raise Riml::UserArgumentError, "can't have more than 20 parameters for #{full_name}"
      end
      expressions.nodes.select { |node| DefNode === node}.each do |nested_func|
        nested_func.nested_within.unshift(self)
      end
    end

    SPLAT = lambda {|arg| arg == Riml::Constants::SPLAT_LITERAL || arg[0] == "*"}
    DEFAULT_PARAMS = lambda {|p| DefaultParamNode === p}

    def original_name
      @original_name ||= name
    end
    attr_writer :original_name

    # ["arg1", "arg2"}
    def argument_variable_names
      parameters.reject(&SPLAT)
    end

    def shadowed_argument?(var_name)
      shadowed_argument_variable_names.include?(var_name)
    end

    def shadowed_argument_variable_names
      @shadowed_argument_variable_names ||= Set.new
    end

    def nested_within
      @nested_within ||= []
    end

    def nested_function?
      not nested_within.empty?
    end

    # returns the splat argument or nil
    def splat
      parameters.detect(&SPLAT)
    end

    def keywords
      if name.include?('.')
        (super.to_a + ['dict'])
      else
        super.to_a
      end.uniq
    end

    def defined_on_dictionary?
      keywords.include?('dict')
    end

    def autoload?
      name.include?('#')
    end

    alias sid? sid

    def super_node
      expressions.nodes.detect {|n| SuperNode === n}
    end

    def to_scope
      ScopeNode.new.tap do |scope|
        scope.argument_variable_names += argument_variable_names
        scope.function = self
      end
    end

    def default_param_nodes
      parameters.select(&DEFAULT_PARAMS)
    end

    def children
      children = if sid?
        [sid, expressions]
      else
        [expressions]
      end
      children.concat(default_param_nodes)
    end

    def method_missing(method, *args, &blk)
      if children.respond_to?(method)
        children.send(method, *args, &blk)
      else
        super
      end
    end
  end

  class DefaultParamNode < Struct.new(:parameter, :expression)
    include Visitable
    include Walkable

    def children
      [parameter, expression]
    end
  end

  class ScopeNode
    attr_writer :for_node_variable_names, :argument_variable_names
    attr_accessor :function

    def for_node_variable_names
      @for_node_variable_names ||= Set.new
    end

    def argument_variable_names
      @argument_variable_names ||= Set.new
    end

    alias function? function

    def initialize_copy(source)
      super
      self.for_node_variable_names = for_node_variable_names.dup
      self.argument_variable_names = argument_variable_names.dup
      self.function = source.function
    end

    def merge(other)
      dup.merge! other
    end

    def merge!(other)
      unless other.is_a?(ScopeNode)
        raise ArgumentError, "other must be ScopeNode, is #{other.class}"
      end
      self.for_node_variable_names += other.for_node_variable_names
      self.argument_variable_names -= for_node_variable_names
      self.function = other.function
      self
    end
  end

  class DefMethodNode < DefNode
    def to_def_node
      def_node = DefNode.new(bang, sid, 's:', name, parameters, ['dict'], expressions)
      def_node.parent = parent
      def_node
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

    def wrap_condition_in_parens!
      return if WrapInParensNode === condition
      _parent = condition.parent
      self.condition = WrapInParensNode.new(condition)
      self.condition.parent = _parent
    end
  end

  class IfNode < ControlStructure
    include NotNestedUnder
  end
  class WhileNode < ControlStructure; end

  class UnlessNode < IfNode
    def initialize(*)
      super
      wrap_condition_in_parens!
    end
  end
  class UntilNode < ControlStructure
    def initialize(*)
      super
      wrap_condition_in_parens!
    end
  end

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

  class ElseifNode < ControlStructure
    include Visitable
    include Walkable
    alias expressions body

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
      [condition, body]
    end
  end

  # for variable in someFunction(1,2,3)
  #   echo variable
  # end
  #
  # OR
  #
  # for variable in [1,2,3]
  #   echo variable
  # end
  class ForNode < Struct.new(:variable, :in_expression, :expressions)
    include Visitable
    include Indentable
    include Walkable

    alias for_variable variable

    def variables
      variable if ListNode === variable
    end

    def for_node_variable_names
      if ListNode === variable
        variable.value.map(&:name)
      else
        [variable]
      end
    end

    def to_scope
      ScopeNode.new.tap {|s| s.for_node_variable_names += for_node_variable_names}
    end

    def children
      [variable, in_expression, expressions]
    end
  end

  class DictGetNode < Struct.new(:dict, :keys)
    include Visitable
    include Walkable

    def children
      [dict] + keys
    end
  end

  # dict['key']
  # dict['key1']['key2']
  class DictGetBracketNode < DictGetNode
  end

  # dict.key
  # dict.key.key2
  class DictGetDotNode < DictGetNode
  end


  # list_or_dict[0]
  # function()[identifier]
  class ListOrDictGetNode < Struct.new(:list_or_dict, :keys)
    include Visitable
    include Walkable

    alias list list_or_dict
    alias dict list_or_dict
    def children
      [list_or_dict] + keys
    end
  end

  class GetVariableByScopeAndDictNameNode < Struct.new(:scope_modifier, :keys)
    include Visitable
    include Walkable

    def children
      [scope_modifier] + keys
    end
  end

  class TryNode < Struct.new(:try_block, :catch_nodes, :finally_block)
    include Visitable
    include Indentable
    include Walkable

    def children
      [try_block] + catch_nodes.to_a + [finally_block].compact
    end
  end

  class CatchNode < Struct.new(:regexp, :expressions)
    include Visitable
    include Walkable
    include NotNestedUnder

    def children
      [expressions]
    end

  end

  class ClassDefinitionNode < Struct.new(:scope_modifier, :name, :superclass_name, :expressions)
    include Visitable
    include Walkable

    FUNCTIONS = lambda {|expr| DefNode === expr}
    DEFAULT_SCOPE_MODIFIER = 's:'

    def initialize(*)
      super
      unless scope_modifier
        self.scope_modifier = DEFAULT_SCOPE_MODIFIER
      end
      # registered with ClassMap
      @registered_state = false
    end

    def superclass?
      not superclass_name.nil?
    end

    def full_name
      scope_modifier + name
    end

    alias superclass_full_name superclass_name

    def constructor
      expressions.nodes.detect do |n|
        next(false) unless DefNode === n && (n.name == 'initialize' || n.name == constructor_name)
        if n.instance_of?(DefMethodNode)
          Riml.warn("class #{full_name.inspect} has an initialize function declared with 'defm'. Please use 'def'.")
          new_node = n.to_def_node
          new_node.keywords = nil
          n.replace_with(new_node)
        end
        true
      end
    end
    alias constructor? constructor

    def find_function(scope_modifier, name)
      expressions.nodes.select(&FUNCTIONS).detect do |def_node|
        def_node.name == name && def_node.scope_modifier == scope_modifier
      end
    end
    alias has_function? find_function

    def constructor_name
      "#{name}Constructor"
    end

    def constructor_full_name
      "#{scope_modifier}#{name}Constructor"
    end

    def constructor_obj_name
      name[0].downcase + name[1..-1] + "Obj"
    end

    def private_function_names
      @private_function_names ||= []
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
end
