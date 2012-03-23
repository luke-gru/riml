require File.expand_path('../nodes', __FILE__)

# visits AST nodes and translates them into Vimscript
#
module Riml
  class Compiler

    # abstract
    class Visitor
      def visit(node)
        raise "have to provide a visit method for #{self.class}"
      end

      def self.compiled_output
        @compiled_output ||= ""
      end
    end

    class NodesVisitor < Visitor
      # nodes
      def visit(nodes)
        nodes.each do |node|
          node = node.first if Array === node
          visitor = Compiler.const_get("#{node.class.name}Visitor")
          node.accept(visitor.new)
        end
      end
    end

    class LiteralNodeVisitor < Visitor
      # value
      def visit(node)
        result = _compile(node.value)
      end

      private
      def _compile(value)
        @compiled = case value
        when TrueClass
          1
        when NilClass, FalseClass
          0
        when String
          value
        end.to_s
        Visitor.compiled_output << @compiled
      end
    end

    TrueNodeVisitor = LiteralNodeVisitor
    FalseNodeVisitor = LiteralNodeVisitor
    NilNodeVisitor = LiteralNodeVisitor
    StringNodeVisitor = LiteralNodeVisitor
    NumberNodeVisitor = LiteralNodeVisitor

    class DefNodeVisitor < Visitor
      # name, params, body
      def visit(node)
        name = node.name
        params = node.params
        body = node.body
        _compile(name, params, body)
      end

      private
      def _compile(name, params, body)
        @compiled = <<Viml.chomp
function #{name}(#{params.join(', ')})\n
Viml
        Visitor.compiled_output << @compiled
        body.accept(NodesVisitor.new)
        Visitor.compiled_output << "endfunction\n"
      end
    end

    def compile(ast)
      root_visitor = NodesVisitor.new
      ast.accept(root_visitor)
      Visitor.compiled_output
    end

  end
end
