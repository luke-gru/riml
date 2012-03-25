require File.expand_path('../nodes', __FILE__)

# visits AST nodes and translates them into VimL
#
module Riml
  class Compiler

    # abstract
    class Visitor
      def visit(node)
        raise "have to provide a visit method for #{self.class}"
      end
    end

    class BranchVisitor < Visitor
      def visit(nodes)
        _set_explicit_returns_on_rightmost_terminals!(nodes)
      end

      private
      def _set_explicit_returns_on_rightmost_terminals!(nodes)
        rightmost_terminals = nodes.accept(NodesDrillDownRight.new)
        rightmost_terminals.each do |t|
          value = t.accept LiteralNodeVisitor.new(:propogate => false)
          nodes.compiled_output.gsub!(/(#{value})/, 'return \1' + "\n")
        end
      end
    end

    class NodesDrillDownRight
      def visit(nodes)
        terminals = []
        nodes.each do |node|
          case node
          when Nodes
            visit(node.nodes)
          when Array
            node.each {|n| visit(n)}
          when LiteralNode
            terminals << node
          when DefNode
            visit(node.body)
          end
        end
        terminals
      end
    end

    class NodesVisitor < Visitor
      def visit(nodes)
        nodes.each do |node|
          visitor = Compiler.const_get("#{node.class.name}Visitor").new
          node.parent_node = nodes
          node.accept(visitor)
        end
      end
    end

    class LiteralNodeVisitor < Visitor

      attr_reader :options
      def initialize(options={})
        @options = {:propogate => true}.merge(options)
      end
      # value
      def visit(node)
        _compile(node)
      end

      private
      def _compile(node)
        compiled = case node.value
        when TrueClass
          1
        when NilClass, FalseClass
          0
        when String
          node.value
        end.to_s
        node.parent_node.compiled_output << compiled if @options[:propogate]
        compiled
      end
    end

    TrueNodeVisitor   = LiteralNodeVisitor
    FalseNodeVisitor  = LiteralNodeVisitor
    NilNodeVisitor    = LiteralNodeVisitor
    StringNodeVisitor = LiteralNodeVisitor
    NumberNodeVisitor = LiteralNodeVisitor

    class DefNodeVisitor < Visitor
      # name, params, body
      def visit(node)
        _compile(node)
      end

      private
      def _compile(node)
        modifier = node.scope_modifier || 's:'
        declaration = <<Viml.chomp
function #{modifier}#{node.name}(#{node.params.join(', ')})\n
Viml
        node.body.accept(NodesVisitor.new)
        # make sure all branches of execution return their values
        node.body.accept(BranchVisitor.new)
        # no nesting functions
        indent = " " * 2
        body = ""
        # have to get node.body.compiled_output manually because NodesVisitors
        # don't propogate their subject's compiled output up the tree.
        node.body.compiled_output.each_line do |line|
          body << indent << line
        end
        method = declaration << body << "endfunction\n"
        node.parent_node.compiled_output << method
      end
    end

    def compile(ast)
      ast.parent_node = nil #root node
      root_visitor = NodesVisitor.new
      ast.accept(root_visitor)
      ast.compiled_output
    end

  end
end
