module Riml
  class AST_Rewriter
    attr_reader :ast
    def initialize(ast)
      @ast = ast
    end

    def rewrite
      VariableEqBinaryOp.new(ast).rewrite
      ast
    end

    class VariableEqBinaryOp < AST_Rewriter
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
        set_var_true  = old_set_var.clone.tap {|sv_t| sv_t.value = TrueNode.new }
        set_var_false = old_set_var.clone.tap {|sv_f| sv_f.value = FalseNode.new }
        node.nodes = [
          IfNode.new(old_binary_op, Nodes.new([
            set_var_true, ElseNode.new(Nodes.new([
            set_var_false
            ]))
          ]))
        ]
      end
    end
  end
end
