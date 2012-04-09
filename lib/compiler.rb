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
        outdent = ""
        condition_visitor = visitor_for_node(node.condition)
        node.condition.parent_node = node
        node.body.parent_node = node
        node.compiled_output = "if ("
        node.compiled_output << "!" if node.respond_to? :unless

        node.condition.accept(condition_visitor)
        node.compiled_output << ")\n"
        pre_body = node.compiled_output; node.compiled_output = ''
        node.body.accept(NodesVisitor.new)

        node.compiled_output.each_line do |line|
          line =~ /else\n\Z/ ? pre_body << outdent << line : pre_body << indent << line
        end
        node.compiled_output = pre_body
        node.compiled_output << outdent << "endif\n"
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
          'nil'
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

    class SetVariableNodeVisitor < Visitor
      def visit(node)
        _compile(node)
        propagate_up_tree(node, @value)
      end

      private
      def _compile(node)
        value_visitor = visitor_for_node(node.value)
        value_visitor.propagate_up_tree = false
        node.value.accept(value_visitor)

        modifier = node.scope_modifier || 's:'

        if node.value.compiled_output == 'nil'
          @value = node.compiled_output = "unlet! #{modifier}#{node.name}" << "\n"
          return
        end
        value_visitor.propagate_up_tree = true

        node.compiled_output = "#{modifier}#{node.name} = "
        node.value.compiled_output.clear
        node.value.parent_node = node
        node.value.accept(value_visitor)
        @value = node.compiled_output << "\n"
      end
    end

    class DefNodeVisitor < Visitor
      # name, params, body
      def visit(node)
        _compile(node)
        propagate_up_tree(node, @value)
      end

      private
      def _compile(node)
        modifier = node.scope_modifier || 's:'
        declaration = <<Viml.chomp
function #{modifier}#{node.name}(#{node.params.join(', ')})\n
Viml
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
    end

    class CallNodeVisitor < Visitor
      def visit(node)
        _compile(node)
        propagate_up_tree(node, @value)
      end

      private
      def _compile(node)
        node.compiled_output = "#{node.method}("
        node.arguments.each_with_index do |arg, i|
          arg.parent_node = node
          arg_visitor = visitor_for_node(arg)
          arg.accept(arg_visitor)
          node.compiled_output << ", " if not_last_arg?(node.arguments, i)
        end
        node.compiled_output << ")"
        # TODO: need better heuristics for adding the newline after calling a
        # function
        unless IfNode === node.parent_node
          node.compiled_output << "\n"
        end
        @value = node.compiled_output
      end

      def not_last_arg?(args, i)
        args[i+1] != nil
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
