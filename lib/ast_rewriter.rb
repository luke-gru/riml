module Riml
  class AST_Rewriter
    attr_reader :ast
    def initialize(ast)
      @ast = ast
    end

    def rewrite
      VariableEqBinaryOpMatch.new(ast).rewrite
      ast
    end

    class VariableEqBinaryOpMatch < AST_Rewriter
      BINARY_OPERATOR_REWRITE_MATCH = /(==|=~|!=|!~)#?/
      def rewrite(nodes = ast)
        case nodes
        when Nodes
          match(nodes) && replace(nodes)
        when ElseNode, ControlStructure, DefNode, ForNode
          nodes.each {|n| rewrite n }
        end
      end

      def match(node)
        Nodes === node &&
        SetVariableNode === node.nodes[0] &&
        BinaryOperatorNode === (op = node.nodes[0].value) &&
        op.operator =~ BINARY_OPERATOR_REWRITE_MATCH
      end

      def replace(node)
        old_binary_op = node.nodes[0].value
        old_set_var = node.nodes[0]
        old_set_var.value = nil
        old_set_var1 = old_set_var.clone.tap {|sv_1| sv_1.value = TrueNode.new }
        old_set_var0 = old_set_var.clone.tap {|sv_2| sv_2.value = FalseNode.new }
        node.nodes = [
          IfNode.new(old_binary_op, Nodes.new([
            old_set_var1, ElseNode.new(Nodes.new([
            old_set_var0
            ]))
          ]))
        ]
      end
    end
  end
end
