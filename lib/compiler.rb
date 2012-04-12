require File.expand_path('../nodes', __FILE__)

# visits AST nodes and translates them into VimL
module Riml
  class Compiler

    # abstract
    class Visitor
      attr_accessor :propagate_up_tree
      attr_reader :value

      def initialize(options={})
        @propagate_up_tree = true unless options[:propagate_up_tree] == false
      end

      def visit(node)
        raise "#{self.class.name} must provide a visit method"
      end

      def propagate_up_tree(node, output)
        node.parent_node.compiled_output << output.to_s unless @propagate_up_tree == false || node.parent_node.nil?
      end

      def visitor_for_node(node)
        Compiler.const_get("#{node.class.name}Visitor").new
      end
    end

    class IfNodeVisitor < Visitor
      def visit(node)
        _compile(node)
        propagate_up_tree(node, @value)
      end

      private
      def _compile(node)
        indent  = " " * 2
        condition_visitor = visitor_for_node(node.condition)
        node.condition.parent_node = node
        node.body.parent_node = node
        node.compiled_output = "if ("
        node.compiled_output << "!" if node.respond_to? :unless

        node.condition.accept(condition_visitor)
        node.compiled_output << ")\n"
        output = node.compiled_output; node.compiled_output = ''
        node.body.accept(NodesVisitor.new)

        node.compiled_output.each_line do |line|
          line =~ /else\n\Z/ ? output << line : output << indent << line
        end
        node.compiled_output = output
        node.compiled_output << "endif\n"
        @value = node.compiled_output
      end
    end

    UnlessNodeVisitor = IfNodeVisitor

    class ElseNodeVisitor < Visitor
      def visit(node)
        _compile(node)
        propagate_up_tree(node, @value)
      end

      private
      def _compile(node)
        node.compiled_output = "else\n"
        expressions_visitor = NodesVisitor.new
        node.expressions.parent_node = node
        node.expressions.accept(expressions_visitor)
        @value = node.compiled_output
      end
    end

    class NodesVisitor < Visitor
      def visit(nodes)
        _compile(nodes)
        propagate_up_tree(nodes, @value)
      end

      private
      def _compile(nodes)
        nodes.each_with_index do |node, i|
          begin
            visitor = visitor_for_node(node)
            next_node = next_node(nodes, i)
            if visitor.class.name =~ /LiteralNode/ && ( node == nodes.last || visitor_for_node(next_node).class.name =~ /ElseNode/ )
              node.explicit_return = true
            end
            node.parent_node = nodes
            node.accept(visitor)
          rescue
            p "Bad Node: #{node.inspect}"
            raise
          end
        end
        @value = nodes.compiled_output
      end

      def next_node(nodes, i)
        nodes.nodes[i+1]
      end

    end


    class LiteralNodeVisitor < Visitor

      def visit(node)
        _compile(node)
        propagate_up_tree(node, @value)
      end

      private
      def _compile(node)
        value = case node.value
        when TrueClass
          1
        when FalseClass
          0
        when NilClass
          nil.inspect
        when String
          if StringNode === node then _escape(node.value) else node.value end
        when Numeric
          node.value
        end.to_s
        @value = node.compiled_output = if node.explicit_return
          "return #{value}\n"
        else
          value
        end
      end

      private
      def _escape(string)
        #TODO: implement
        '"' + string + '"'
      end
    end

    TrueNodeVisitor   = LiteralNodeVisitor
    FalseNodeVisitor  = LiteralNodeVisitor
    NilNodeVisitor    = LiteralNodeVisitor
    StringNodeVisitor = LiteralNodeVisitor
    NumberNodeVisitor = LiteralNodeVisitor
    ReturnNodeVisitor = LiteralNodeVisitor

    # common visiting methods for SetVariableVisitor and GetVariableVisitor
    class VariableVisitor < Visitor
      private
      def _scope_modifier_for_local_variable_name(var_name, scope)
        scope.scoped_variables.reverse_each do |name|
          if name[2..-1] == var_name then return name[0...2] end
        end
        ''
      end

      def _scope_modifier_for_global_variable_name(var_name)
        global_variables.reverse_each do |name|
          if name[2..-1] == var_name then return name[0...2] end
        end
        's:'
      end
    end

    class SetVariableNodeVisitor < VariableVisitor
      def visit(node)
        _compile(node)
        propagate_up_tree(node, @value)
      end

      private
      def _compile(node)
        modifier = node.scope_modifier
        _push_explicitly_scoped_variable_onto_stack("#{modifier}#{node.name}", node) if modifier
        if modifier.nil?
          # local scope
          if node.scope and node.scope.local?
            modifier = _scope_modifier_for_local_variable_name(node.name, node.scope)
          # global scope
          else
            modifier = _scope_modifier_for_global_variable_name(node.name)
          end
        end

        value_visitor = visitor_for_node(node.value)
        value_visitor.propagate_up_tree = false
        node.value.accept(value_visitor)
        if node.value.compiled_output == nil.inspect
          @value = node.compiled_output = "unlet! #{modifier}#{node.name}" << "\n"
          return
        end
        value_visitor.propagate_up_tree = true

        node.compiled_output = "let #{modifier}#{node.name} = "
        node.value.compiled_output.clear
        node.value.parent_node = node
        node.value.accept(value_visitor)
        node.compiled_output << "\n" unless node.compiled_output[-1] == "\n"
        @value = node.compiled_output
      end

      private
      def _push_explicitly_scoped_variable_onto_stack(var_name, node)
        if node.scope and node.scope.local?
          node.scope.scoped_variables << var_name
          node.scope.scoped_variables.uniq!
        else
          global_variables << var_name
          global_variables.uniq!
        end
      end
    end

    # scope_modifier, name
    class GetVariableNodeVisitor < VariableVisitor
      def visit(node)
        _compile(node)
        propagate_up_tree(node, @value)
      end

      private
      def _compile(node)
        modifier = node.scope_modifier
        if modifier.nil?
          # local scope
          if node.scope and node.scope.local?
            modifier = _scope_modifier_for_local_variable_name(node.name, node.scope)
          # global scope
          else
            modifier = _scope_modifier_for_global_variable_name(node.name)
          end
        end
        if node.question_existence?
          node.compiled_output = "exists?(\"#{modifier}#{node.name}\")"
        else
          node.compiled_output = "#{modifier}#{node.name}"
        end
        @value = node.compiled_output
      end
    end

    # operator, operands
    class BinaryOperatorNodeVisitor < Visitor
      def visit(node)
        _compile(node)
        propagate_up_tree(node, @value)
      end

      private
      def _compile(node)
        operand1_visitor = visitor_for_node(node.operand1)
        operand2_visitor = visitor_for_node(node.operand2)
        node.operands.each {|n| n.parent_node = node}
        node.operand1.accept(operand1_visitor)
        node.compiled_output << " #{node.operator} "
        node.operand2.accept(operand2_visitor)
        @value = node.compiled_output
      end
    end

    # scope_modifier, name, parameters, keyword, body, indent
    class DefNodeVisitor < Visitor
      def visit(node)
        _setup_local_scope_for_descendants(node)
        _compile(node)
        propagate_up_tree(node, @value)
      end

      private
      def _compile(node)
        modifier = node.scope_modifier || 's:'
        declaration = <<Viml.chomp
function #{modifier}#{node.name.capitalize}(#{node.parameters.join(', ')})
Viml
        declaration << (node.keyword ? " #{node.keyword}\n" : "\n")
        node.body.parent_node = node
        node.body.accept NodesVisitor.new(:propagate_up_tree => false)
        indent = " " * 2
        body = ""
        node.body.compiled_output.each_line do |line|
          body << indent << line
        end
        node.compiled_output = declaration << body << "endfunction\n"
        @value = node.compiled_output
      end

      def _setup_local_scope_for_descendants(node)
        node.body.accept(DrillDownVisitor.new(:establish_scope => true, :scope => node))
      end
    end

    # helper to drill down to all descendants of a certain node and do
    # something to all or a set of them
    class DrillDownVisitor < Visitor

      def initialize(options={})
        if options[:establish_scope]
          @establish_scope = true
          @scope = options[:scope]
          raise ArgumentError, "need to pass scope to new instance in order to establish scope" unless @scope
        end
        super
      end

      def visit(node)
        if @establish_scope
          _establish_scope(node)
        else
        end
      end

      private
      def _establish_scope(node)
        node.scope = @scope

        case node
        when Nodes
          node.each do |expr|
            expr.accept(self)
          end
        when IfNode # includes UnlessNode
          node.condition.scope = @scope
          node.each do |body_expr|
            body_expr.accept(self)
          end
        when ElseNode
          node.each do |else_expr|
            else_expr.accept(self)
          end
        else
          #p "Node not caught while drilling down: #{node}"
        end
      end
    end

    class CallNodeVisitor < Visitor
      def visit(node)
        _compile(node)
        propagate_up_tree(node, @value)
      end

      private
      def _compile(node)
        node.compiled_output = "#{node.scope_modifier}#{node.name}("
        node.arguments.each_with_index do |arg, i|
          arg.parent_node = node
          arg_visitor = visitor_for_node(arg)
          arg.accept(arg_visitor)
          node.compiled_output << ", " unless last_arg?(node.arguments, i)
        end
        node.compiled_output << ")"

        unless node.descendant_of_if_node? || node.descendant_of_call_node?
          node.compiled_output << "\n"
        end
        @value = node.compiled_output
      end

      def last_arg?(args, i)
        args[i+1].nil?
      end
    end


    # compiles nodes into output code
    def compile(root_node)
      root_node.parent_node = nil
      root_visitor = NodesVisitor.new
      root_node.accept(root_visitor)
      root_node.compiled_output
    end

  end
end
