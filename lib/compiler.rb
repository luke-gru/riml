require File.expand_path('../nodes', __FILE__)

# visits AST nodes and translates them into VimL
module Riml
  class Compiler

    def self.debug?
      not ENV["RIML_DEBUG"].nil?
    end

    # Map of compiled global variable names to the type of node that they represent.
    #
    # Ex: {"s:string" => :StringNode}
    def self.global_variables
      @global_variables ||= {}
    end

    # Map of compiled 'special' variable names to the type of node that they
    # represent
    #
    # Ex: {"$SOME_VAR" => :NumberNode, "&Another" => :StringNode}
    def self.special_variables
      @special_variables ||= {}
    end

    # Base abstract visitor
    class Visitor
      attr_accessor :propagate_up_tree
      attr_reader :value

      def initialize(options={})
        @propagate_up_tree = options[:propagate_up_tree]
      end

      def visit(node)
        @value = compile(node)
        propagate_up_tree(node, @value)
      end

      def propagate_up_tree(node, output)
        node.parent_node.compiled_output << output.to_s unless @propagate_up_tree == false || node.parent_node.nil?
      end

      def visitor_for_node(node, params={})
        Compiler.const_get("#{node.class.name}Visitor").new(params)
      end
    end

    class IfNodeVisitor < Visitor
      def compile(node)
        condition_visitor = visitor_for_node(node.condition)
        node.condition.parent_node = node
        node.body.parent_node = node
        node.compiled_output = "if ("
        node.compiled_output << "!" if UnlessNode === node

        node.condition.accept(condition_visitor)
        node.compiled_output << ")\n"
        output = node.compiled_output; node.compiled_output = ''
        node.body.accept(NodesVisitor.new)

        node.compiled_output.each_line do |line|
          line =~ /else\n\Z/ ? output << line : output << node.indent + line
        end
        node.compiled_output = output
        node.compiled_output << "endif\n"
      end
    end

    UnlessNodeVisitor = IfNodeVisitor

    class TernaryOperatorNodeVisitor < Visitor
      def compile(node)
        node.operands.each {|n| n.parent_node = node}
        cond_visitor = visitor_for_node(node.condition)
        node.condition.accept(cond_visitor)
        node.compiled_output << ' ? '
        if_expr_visitor = visitor_for_node(node.if_expr)
        node.if_expr.accept(if_expr_visitor)
        node.compiled_output << ' : '
        else_expr_visitor =  visitor_for_node(node.else_expr)
        node.else_expr.accept(else_expr_visitor)
        node.compiled_output
      end
    end

    class WhileNodeVisitor < Visitor
      def compile(node)
        cond_visitor = visitor_for_node(node.condition)
        node.condition.parent_node = node
        node.body.parent_node = node
        node.compiled_output = "while ("
        node.compiled_output << "!" if UntilNode === node

        node.condition.accept(cond_visitor)
        node.compiled_output << ")\n"

        output = node.compiled_output.dup
        node.compiled_output.clear

        node.body.accept(NodesVisitor.new)
        node.compiled_output.each_line do |line|
          output << node.indent + line
        end
        node.compiled_output = output << "\n"
        node.compiled_output << "endwhile\n"
      end
    end

    UntilNodeVisitor = WhileNodeVisitor

    class ElseNodeVisitor < Visitor
      def compile(node)
        node.compiled_output = "else\n"
        expressions_visitor = NodesVisitor.new
        node.expressions.parent_node = node
        node.expressions.accept(expressions_visitor)
        node.compiled_output
      end
    end

    class NodesVisitor < Visitor
      def compile(nodes)
        nodes.each_with_index do |node, i|
          begin
            visitor = visitor_for_node(node)
            next_node = nodes.nodes[i+1]
            if LiteralNode === node &&
              !(node.respond_to?(:omit_return) && node.omit_return) &&
              (node == nodes.last || ElseNode === next_node)
              node.explicit_return = true
            end
            node.parent_node = nodes
            node.accept(visitor)
          rescue
            STDERR.puts "Bad Node: #{node.inspect}" if Compiler.debug?
            raise
          end
        end
        nodes.compiled_output
      end
    end

    class LiteralNodeVisitor < Visitor
      def compile(node)
        value = case node.value
        when TrueClass
          1
        when FalseClass
          0
        when NilClass
          'nil'
        when String
          StringNode === node ? escape(node) : node.value.dup
        when Array
          node.value.each {|n| n.parent_node = node}
          '[' << node.value.map {|n| compile(n)}.join(', ') << ']'
        when Hash
          node.value.each {|k_n, v_n| k_n.parent_node, v_n.parent_node = [node, node]}
          '{' << node.value.map {|k,v| compile(k) << ': ' << compile(v)}.join(', ') << '}'
        when Numeric
          node.value
        end.to_s

        node.compiled_output = begin
          if node.explicit_return
            "return #{value}\n"
          else
            value
          end
        end
      rescue NoMethodError
        if GetVariableNode === node
          node.accept(GetVariableNodeVisitor.new)
          node.compiled_output
        else raise end
      end

      private
      def escape(string_node)
        case string_node.type
        when :d
          '"' << string_node.value << '"'
        when :s
          "'" << string_node.value << "'"
        end
      end
    end

    TrueNodeVisitor  = LiteralNodeVisitor
    FalseNodeVisitor = LiteralNodeVisitor
    NilNodeVisitor   = LiteralNodeVisitor

    NumberNodeVisitor = LiteralNodeVisitor
    StringNodeVisitor = LiteralNodeVisitor
    RegexpNodeVisitor = LiteralNodeVisitor

    ListNodeVisitor = LiteralNodeVisitor
    DictionaryNodeVisitor = LiteralNodeVisitor

    ReturnNodeVisitor = LiteralNodeVisitor
    FinishNodeVisitor = LiteralNodeVisitor
    ContinueNodeVisitor = LiteralNodeVisitor
    BreakNodeVisitor = LiteralNodeVisitor

    # common visiting methods for nodes that are scope modified with prefixes
    class ScopedVisitor < Visitor
      private
      def set_modifier(node)
        # Ex: n:myVariable = "override riml default scoping" compiles into:
        #       myVariable = "override riml default scoping"
        return node.scope_modifier = "" if node.scope_modifier == "n:"
        return node.scope_modifier if node.scope_modifier
        node.scope_modifier = get_scope_modifier_for_variable_name(node)
      end

      # `@variable_map` is a mapping of scope_modified local variable names
      # to the type of the value that they represent
      def get_scope_modifier_for_variable_name(node)
        get_variable_map_for_node(node)
        if @local_scope
          default_modifier = ''
        else
          default_modifier = 's:'
        end
        @variable_map.keys.each do |name|
          return name[0..1] if name[2..-1] == node.name
        end
        default_modifier
      end

      def get_variable_map_for_node(node)
        @variable_map ||= begin
          if node.scope and node.scope.local_scope?
            @local_scope = true
            node.scope.scoped_variables.merge!(node.scope.arg_variables)
          elsif node.respond_to?(:prefix)
            Compiler.special_variables
          else
            Compiler.global_variables
          end
        end
      end

      def associate_variable_name_with_type(node)
        get_variable_map_for_node(node)
        # ex: {"b:a" => :NilNode}
        @variable_map[node.full_name] = node.value.class.name.to_sym
        STDERR.puts @variable_map.inspect if Compiler.debug?
      end

      def get_type_for_node(node)
        get_variable_map_for_node(node)
        @variable_map.each do |name, type|
          return type if node.full_name == name
        end
        nil
      end
    end

    class SetVariableNodeVisitor < ScopedVisitor
      def compile(node)
        set_modifier(node)
        associate_variable_name_with_type(node)

        value_visitor = visitor_for_node(node.value)
        node.compiled_output = "let #{node.full_name} = "
        node.value.parent_node = node
        node.value.accept(value_visitor)
        node.compiled_output = "unlet! #{node.full_name}" if node.value.compiled_output == 'nil'

        node.compiled_output << "\n" unless node.compiled_output[-1] == "\n"
        node.compiled_output
      end
    end

    # list, expression
    class SetVariableNodeListVisitor < Visitor
      def compile(node)
        node.compiled_output = "let "
        node.list.parent_node = node
        node.list.accept(ListNodeVisitor.new)
        node.compiled_output << " = "
        node.expression.parent_node = node
        node.expression.accept(visitor_for_node(node.expression))
        node.compiled_output
      end
    end

    class SetSpecialVariableNodeVisitor < ScopedVisitor
      def compile(node)
        associate_variable_name_with_type(node)
        node.compiled_output = "let #{node.full_name} = "
        value_visitor = visitor_for_node(node.value)
        node.value.parent_node = node
        node.value.accept(value_visitor)
        node.compiled_output << "\n" unless node.compiled_output[-1] == "\n"
        node.compiled_output
      end
    end

    # scope_modifier, name
    class GetVariableNodeVisitor < ScopedVisitor
      def compile(node)
        # the variable is a ForNode variable
        scope = node.parent_node && node.parent_node.scope
        if scope && scope.respond_to?(:for_variable) &&
           scope.for_variable == node.name && node.scope_modifier.nil?
          return node.name
        end

        set_modifier(node)
        type = get_type_for_node(node)
        node.node_type = type
        if node.scope && node.scope.respond_to?(:splat) && (splat = node.scope.splat)
          check_for_splat_match!(node, splat)
        end
        if node.question_existence?
          node.compiled_output = %Q{exists("#{node.full_name}")}
        else
          node.compiled_output = "#{node.full_name}"
        end
      end

      private
      def check_for_splat_match!(node, splat)
        if node.name == splat[1..-1]
          @modifier = nil
          node.name = 'a:000'
        end
      end
    end

    class GetSpecialVariableNodeVisitor < ScopedVisitor
      def compile(node)
        type = get_type_for_node(node)
        node.node_type = type
        node.compiled_output = node.full_name
      end
    end

    class GetCurlyBraceNameNodeVisitor < ScopedVisitor
      def compile(node)
        node.compiled_output = node.scope_modifier || 's:'
        node.variable.parts.each do |part|
          node.compiled_output <<
          if part.interpolated?
            part.value.accept(visitor_for_node(part.value))
            "{#{part.value.compiled_output}}"
          else
            "#{part.value}"
          end
        end
        node.compiled_output
      end
    end

    # operator, operands
    class BinaryOperatorNodeVisitor < Visitor
      def compile(node)
        op1, op2 = node.operand1, node.operand2
        op1_visitor, op2_visitor = visitor_for_node(op1), visitor_for_node(op2)
        node.operands.each {|n| n.parent_node = node}
        op1.accept(op1_visitor)
        op2_visitor.propagate_up_tree = false
        op2.accept(op2_visitor)
        if ignorecase_capable?(node.operator) && operands_are_string_nodes?(op1, op2)
          operator_suffix = "# "
        else
          operator_suffix = " "
        end
        node.compiled_output << " #{node.operator}#{operator_suffix}"
        op2_visitor.propagate_up_tree = true
        op2.accept(op2_visitor)
        node.compiled_output
      end

      private
      def operands_are_string_nodes? *nodes
        nodes.all? do |n|
          n.is_a?(StringNode) || (n.respond_to?(:node_type) && n.node_type == :StringNode)
        end
      end

      def ignorecase_capable? operator
        %w(== !=).include? operator
      end
    end

    # scope_modifier, name, parameters, keyword, body
    class DefNodeVisitor < Visitor
      def visit(node)
        setup_local_scope_for_descendants(node)
        super
      end

      def compile(node)
        modifier = node.scope_modifier || 's:'
        params = process_parameters!(node)
        declaration = "function! #{modifier}"
        declaration <<
        if node.name.respond_to?(:variable)
          node.name.accept(visitor_for_node(node.name))
          node.name.compiled_output
        else
          node.name
        end << "(#{params.join(', ')})"
        declaration << (node.keyword ? " #{node.keyword}\n" : "\n")
        node.body.parent_node = node
        node.body.accept NodesVisitor.new(:propagate_up_tree => false)

        body = ""
        unless node.body.compiled_output.empty?
          node.body.compiled_output.each_line do |line|
            body << node.indent + line
          end
        end
        node.compiled_output = declaration << body << "endfunction\n"
      end

      private
      def setup_local_scope_for_descendants(node)
        node.body.accept(DrillDownVisitor.new(:establish_scope => node))
      end

      def process_parameters!(node)
        splat = node.splat
        return node.parameters unless splat
        node.parameters.map {|p| p == splat ? '...' : p}
      end
    end

    # helper to drill down to all descendants of a certain node and do
    # something to all or a set of them
    class DrillDownVisitor < Visitor

      def initialize(options={})
        if options[:establish_scope]
          @scope = @establish_scope = options[:establish_scope]
        end
        super
      end

      def visit(node)
        if @establish_scope
          establish_scope(node)
        end
      end

      private
      def establish_scope(node)
        node.scope = @scope

        case node
        when Nodes, ElseNode
          node.each do |expr|
            expr.accept(self)
          end
        when ControlStructure
          node.condition.scope = @scope
          node.each do |body_expr|
            body_expr.accept(self)
          end
        when CallNode
          node.arguments.each do |arg|
            arg.accept(self)
          end
        when SetVariableNode
          node.value.accept(self)
        end
      end
    end

    class CallNodeVisitor < ScopedVisitor
      def compile(node)
        set_modifier(node) unless node.builtin_function?
        node.compiled_output =
        if node.name.respond_to?(:variable)
          node.name.accept(visitor_for_node(node.name))
          node.scope_modifier + node.name.compiled_output
        else
          "#{node.full_name}"
        end
        node.compiled_output << (node.no_parens_necessary? ? " " : "(")
        node.arguments.each_with_index do |arg, i|
          arg.parent_node = node
          arg_visitor = visitor_for_node(arg)
          arg.accept(arg_visitor)
          node.compiled_output << ", " unless last_arg?(node.arguments, i)
        end
        node.compiled_output << ")" unless node.no_parens_necessary?

        unless node.descendant_of_control_structure? ||
               node.descendant_of_call_node? ||
               node.descendant_of_list_or_dict_get_node?
          node.compiled_output << "\n"
        end
        node.compiled_output
      end

      private
      def last_arg?(args, i)
        args[i+1].nil?
      end
    end

    class ExplicitCallNodeVisitor < CallNodeVisitor
      def compile(node)
        pre = "call "
        post = super
        node.compiled_output = pre << post
      end
    end

    class ForNodeVisitor < Visitor
      def compile(node)
        node.compiled_output = "for #{node.variable} in "
        node.list_expression.parent_node = node
        yield
        node.expressions.parent_node = node
        node.expressions.accept(DrillDownVisitor.new(:establish_scope => node))
        node.expressions.accept(NodesVisitor.new :propagate_up_tree => false)
        body = node.expressions.compiled_output
        body.each_line do |line|
          node.compiled_output << node.indent + line
        end
        node.compiled_output << "endfor"
      end
    end

    class ForNodeCallVisitor < ForNodeVisitor
      def compile(node)
        super do
          node.list_expression.accept(CallNodeVisitor.new)
        end
      end
    end

    class ForNodeListVisitor < ForNodeVisitor
      def compile(node)
        super do
          result = node.list_expression.accept(ListNodeVisitor.new)
          result << "\n" unless result[-1] == "\n"
        end
      end
    end

    class TryNodeVisitor < Visitor
      # try_block, catch_nodes, ensure_block
      def compile(node)
        try, catches, _ensure = node.try_block, node.catch_nodes, node.ensure_block
        node.compiled_output = "try\n"
        try.accept(visitor_for_node(try))
        try.compiled_output.each_line do |line|
          node.compiled_output << node.indent + line
        end

        catches.each do |c|
          c.accept(visitor_for_node(c))
          c.compiled_output.each_line do |line|
            node.compiled_output << ( line =~ /\A\s*catch/ ? line : node.indent + line )
          end
        end if catches

        if _ensure
          node.compiled_output << "finally\n"
          _ensure.accept(visitor_for_node(_ensure))
          _ensure.compiled_output.each_line do |line|
            node.compiled_output << node.indent + line
          end
        end
        node.compiled_output << "endtry\n"
      end
    end

    class CatchNodeVisitor < Visitor
      # regexp, block
      def compile(node)
        regexp, block = node.regexp, node.block
        node.compiled_output = "catch\n"
        block.parent_node = node
        if regexp
          regexp.parent_node = node
          regexp.accept(visitor_for_node(regexp))
        end
        block.accept(visitor_for_node(block))
        node.compiled_output
      end
    end

    class DictGetBracketNodeVisitor < ScopedVisitor
      def compile(node)
        node.dict.parent_node = node
        node.keys.each {|k| k.parent_node = node}
        node.dict.accept(visitor_for_node(node.dict))
        node.keys.each do |key|
          node.compiled_output << '['
          key.accept(visitor_for_node(key))
          node.compiled_output << "]"
        end
        node.compiled_output
      end
    end

    class DictGetDotNodeVisitor < ScopedVisitor
      def compile(node)
        node.dict.parent_node = node
        node.dict.accept(visitor_for_node(node.dict))
        node.keys.each do |key|
          node.compiled_output << ".#{key}"
        end
        node.compiled_output
      end
    end

    class DictSetNodeVisitor < ScopedVisitor
      def compile(node)
        [node.dict, node.val].each {|n| n.parent_node = node}
        node.compiled_output = "let "
        node.dict.accept(visitor_for_node(node.dict))
        node.keys.each {|k| node.compiled_output << ".#{k}"}
        node.compiled_output << " = "
        node.val.accept(visitor_for_node(node.val))
        node.compiled_output << "\n"
      end
    end

    class ListOrDictGetNodeVisitor < DictGetBracketNodeVisitor; end

    # compiles nodes into output code
    def compile(root_node)
      root_visitor = NodesVisitor.new
      root_node.accept(root_visitor)
      root_node.compiled_output
    end

  end
end
