require File.expand_path('../constants', __FILE__)
require File.expand_path('../errors', __FILE__)
require File.expand_path('../walkable', __FILE__)
require 'set'

module Riml
  module Visitable
    include Walkable

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

    EMPTY_CHILDREN = [].freeze

    def children
      EMPTY_CHILDREN
    end

    def location_info
      n = self
      while n != nil && !n.parser_info
        n = n.parent
      end
      if n.nil?
        return Constants::UNKNOWN_LOCATION_INFO
      end
      filename = parser_info[:filename] || Constants::COMPILED_STRING_LOCATION
      "#{filename}:#{parser_info[:lineno]}"
    end

    def force_newline_if_child_call_node?
      true
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

    def children
      nodes
    end
  end

  class SublistNode < Nodes
    def force_newline_if_child_call_node?
      false
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

  class StringLiteralConcatNode < Struct.new(:string_nodes)
    include Visitable

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

    def initialize(ary)
      unless Array === ary
        raise ArgumentError, "#{self.class} expects an Array, got: #{ary.class}"
      end
      super
    end

    def self.wrap(value)
      val = Array === value ? value : [value]
      new(val)
    end

    def force_newline_if_child_call_node?
      false
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

    def initialize(value)
      super(value.to_a)
    end

    def force_newline_if_child_call_node?
      false
    end

    def children
      ret = []
      value.compact.each { |(k, v)| ret << k << v }
      ret
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

  # Used for splats in a calling context.
  # Ex: `super(*args)`,  `super(*a:000)`, `someFunc(*(list + ['item']))`
  class SplatNode < Struct.new(:expression)
    include Visitable

    def children
      [expression]
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

    def children
      [expression]
    end
  end

  class WrapInParensNode < Struct.new(:expression)
    include Visitable

    def force_newline_if_child_call_node?
      false
    end

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

    attr_accessor :super_call

    ALL_BUILTIN_FUNCTIONS = BUILTIN_FUNCTIONS + BUILTIN_COMMANDS
    ALL_BUILTIN_COMMANDS  = BUILTIN_COMMANDS  + RIML_COMMANDS + VIML_COMMANDS

    def initialize(scope_modifier, name, arguments)
      super
      remove_parens_wrapper if builtin_command?
    end

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

    def method_call?
      name.instance_of?(DictGetDotNode) &&
        name.dict.name == 'self' &&
        name.dict.scope_modifier.nil?
    end

    alias super_call? super_call

    def autoload?
      name.include?('#')
    end

    def force_newline_if_child_call_node?
      false
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

  # riml_include, riml_source, riml_import
  class RimlCommandNode < CallNode
  end

  # riml_include, riml_source
  class RimlFileCommandNode < RimlCommandNode

    def initialize(*)
      super
      if arguments.empty? || !arguments.all? { |arg| arg.is_a?(StringNode) }
        error = Riml::UserArgumentError.new(
          "#{name.inspect} error: must pass string(s) (name of file(s))",
          self
        )
        raise error
      end
    end

    # yields basename and full file path for each existing file found in
    # Riml.source_path or Riml.include_path
    def each_existing_file!
      files = {}
      # FIXME: This is a bit of a hack, making sure the include path or source
      # path is properly cached in case `Riml.{include|source}_path` hasn't been
      # called already
      path_dirs
      file_variants.each do |(fname_given, fname_ext_added)|
        if (full_path = Riml.path_cache.file(path_dirs, fname_given))
          files[fname_given] = full_path
        elsif (full_path = Riml.path_cache.file(path_dirs, fname_ext_added))
          add_ext_to_filename(fname_given)
          files[fname_ext_added] = full_path
        else
          error_msg = "#{fname_given.inspect} could not be found in " \
            "Riml.#{name.sub('riml_', '')}_path (#{path_dirs.join(':').inspect})"
          error = Riml::FileNotFound.new(error_msg, self)
          raise error
        end
      end
      return files unless block_given?
      # all files exist
      files.each do |basename, full_path|
        begin
          yield basename, full_path
        rescue Riml::IncludeFileLoop, Riml::SourceFileLoop
          arguments.delete_if { |arg| arg.value == basename }
        end
      end
    end

    private

    def path_dirs
      if name == 'riml_include'
        Riml.include_path
      else
        Riml.source_path
      end
    end

    def file_variants
      arguments.map { |arg| file_variants_for_arg(arg) }
    end

    def file_variants_for_arg(arg)
      [arg.value, "#{arg.value}.riml"]
    end

    def add_ext_to_filename(fname)
      arg = arguments.detect { |a| a.value == fname }
      return unless arg
      arg.value = file_variants_for_arg(arg).last
    end
  end

  # riml_import g:ClassName
  class RimlClassCommandNode < RimlCommandNode
    def initialize(*args)
      super
      string_node_arguments.each do |arg|
        class_name = arg.value
        # if '*' isn't a char in `class_name`, raise error
        if class_name.index('*').nil?
          msg = "* must be a character in class name '#{class_name}' if riml_import " \
          "is given a string. Try 'riml_import #{class_name}' instead."
          error = UserArgumentError.new(msg, self)
          raise error
        end
      end
    end

    def class_names_without_modifiers
      arguments.map do |full_name|
        full_name = full_name.value if full_name.respond_to?(:value)
        full_name.sub(/\A\w:/, '')
      end
    end

    def string_node_arguments
      arguments.select { |arg| StringNode === arg }
    end
  end

  class OperatorNode < Struct.new(:operator, :operands)
    include Visitable

    def force_newline_if_child_call_node?
      false
    end

    def children
      operands
    end
  end

  class BinaryOperatorNode < OperatorNode
    include Riml::Constants

    # string together multiple expressions using binary operators with `operand`
    # ex:
    #   BinaryOperatorNode.string_together('.', 'hello', ' world', '!')])
    # returns
    #   BinaryOperatorNode.new('+', 'hello', BinaryOperatorNode.new('+', ' world', ''))
    #
    # @param operand String
    # @param expressions Array
    # @returns BinaryOperatorNode
    def self.string_together(operand, expressions)
      tail = new(operand, [expressions[0], expressions[1]])
      expressions[2..-1].inject(tail) do |expr, memo|
        new(operand, [expr, memo])
      end
    end

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

    def children
      [lhs, rhs]
    end
  end

  class MultiAssignNode < Struct.new(:assigns)
    include Visitable

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
      name_with_question_mark[-1, 1] == '?'
    end
  end

  # s:var
  # var
  class GetVariableNode < Struct.new(:scope_modifier, :name)
    include Visitable
    include FullyNameable
    include QuestionVariableExistence

    def arguments_variable?
      scope_modifier == 'a:' && name == '000'
    end
  end

  # &autoindent
  # @q
  class GetSpecialVariableNode < Struct.new(:prefix, :name)
    include Visitable
    include FullyNameable
  end

  class GetCurlyBraceNameNode < Struct.new(:scope_modifier, :variable)
    include Visitable

    def children
      [variable]
    end
  end

  class CurlyBraceVariable < Struct.new(:parts)
    include Visitable

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

    def interpolated?
      GetVariableNode === value || GetSpecialVariableNode === value ||
        CallNode === value || nested?
    end

    def nested?
      value.is_a?(Array) && value.detect {|part| part.is_a?(CurlyBracePart)}
    end

    def force_newline_if_child_call_node?
      false
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

    attr_accessor :private_function
    alias private_function? private_function

    def initialize(*args)
      super
      # max number of arguments in viml
      if parameters.reject(&DEFAULT_PARAMS).size > 20
        error_msg = "can't have more than 20 parameters for function #{full_name}"
        error = Riml::UserArgumentError.new(error_msg, self)
        raise error
      end
      expressions.nodes.select { |node| DefNode === node}.each do |nested_func|
        nested_func.nested_within.unshift(self)
      end
    end

    SPLAT = lambda {|arg| arg == Riml::Constants::SPLAT_LITERAL || arg.to_s[0, 1] == "*"}
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

    def valid_function_name?
      if name.is_a?(String)
        name =~ Constants::VALID_FUNCTION_NAME_REGEX
      else
        true # FIXME
      end
    end

    alias sid? sid

    # FIXME: only detects top-level super nodes
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

    def is_splat_arg?(node)
      splat = splat()
      return false unless splat
      GetVariableNode === node && node.scope_modifier.nil? && node.name == splat[1..-1]
    end

    def children
      ret = []
      if sid?
        ret << sid
      end
      unless name.is_a?(String)
        ret << name
      end
      ret.concat(default_param_nodes)
      ret << expressions
    end
  end

  class DefaultParamNode < Struct.new(:parameter, :expression)
    include Visitable

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

    def merge(other)
      dup.merge! other
    end

    def merge_parent_function(other)
      dup.merge_parent_function!(other)
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

    def merge_parent_function!(other)
      unless other.is_a?(ScopeNode)
        raise ArgumentError, "other must be ScopeNode, is #{other.class}"
      end
      self.function = other.function
      self.argument_variable_names = other.argument_variable_names
      self.for_node_variable_names = other.for_node_variable_names
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

    def force_newline_if_child_call_node?
      false
    end

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

    alias for_variable variable

    def variables
      variable if ListNode === variable
    end

    def for_node_variable_names
      if ListNode === variable
        variable.value.map(&:name)
      else
        [variable.name]
      end
    end

    def to_scope
      ScopeNode.new.tap do |s|
        s.for_node_variable_names += for_node_variable_names
        s.argument_variable_names = (self.scope && self.scope.argument_variable_names)
        s.function = (self.scope && self.scope.function) || nil
      end
    end

    def children
      [variable, in_expression, expressions]
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
  class DictGetBracketNode < DictGetNode
  end

  # dict.key
  # dict.key.key2
  class DictGetDotNode < DictGetNode
    def force_newline_if_child_call_node?
      false
    end
  end


  # list_or_dict[0]
  # function()[identifier]
  class ListOrDictGetNode < Struct.new(:list_or_dict, :keys)
    include Visitable

    alias list list_or_dict
    alias dict list_or_dict

    def force_newline_if_child_call_node?
      false
    end

    def children
      [list_or_dict] + keys
    end
  end

  class GetVariableByScopeAndDictNameNode < Struct.new(:scope_modifier, :keys)
    include Visitable

    def children
      [scope_modifier] + keys
    end
  end

  class TryNode < Struct.new(:try_block, :catch_nodes, :finally_block)
    include Visitable
    include Indentable

    def children
      [try_block] + catch_nodes.to_a + [finally_block].compact
    end
  end

  class CatchNode < Struct.new(:regexp, :expressions)
    include Visitable
    include NotNestedUnder

    def children
      [expressions]
    end

  end

  class ClassDefinitionNode < Struct.new(:scope_modifier, :name, :superclass_name, :expressions)
    include Visitable

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

    # This if for the AST_Rewriter, checking if a class is an `ImportedClass`
    # or not without resorting to type checking.
    def imported?
      false
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
      name[0, 1].downcase + name[1..-1] + "Obj"
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

    def use_all_arguments?
      arguments.empty? && !with_parens
    end

    def children
      arguments
    end
  end

  class ObjectInstantiationNode < Struct.new(:call_node)
    include Visitable

    def force_newline_if_child_call_node?
      false
    end

    def children
      [call_node]
    end
  end
end
