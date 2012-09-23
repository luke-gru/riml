require File.expand_path(__FILE__, "../constants")

module Riml
  class AST_Rewriter
    include Riml::Constants

    attr_reader :ast
    def initialize(ast)
      @ast = ast
    end

    def rewrite
      StrictEqualsComparisonOperator.new(ast).rewrite_on_match
      VarEqualsComparisonOperator.new(ast).rewrite_on_match
      ast
    end

    def rewrite_on_match(node = ast)
      if match(node)
        replace(node)
      elsif node.respond_to?(:each)
        node.each {|n| rewrite_on_match n }
      end
    end

    class StrictEqualsComparisonOperator < AST_Rewriter
      def match(node)
        BinaryOperatorNode === node && node.operator == '==='
      end

      def replace(node)
        node.operator = '=='
        node.operand1 = ListNode.wrap(node.operand1)
        node.operand2 = ListNode.wrap(node.operand2)
      end
    end

    class VarEqualsComparisonOperator < AST_Rewriter
      COMPARISON_OPERATOR_MATCH = Regexp.union(COMPARISON_OPERATORS)

      def match(node)
        Nodes === node &&
        SetVariableNode === node.nodes[0] &&
        BinaryOperatorNode === (op = node.nodes[0].value) &&
        op.operator =~ COMPARISON_OPERATOR_MATCH
      end

      def replace(node)
        binary_op = node.nodes[0].value
        old_set_var = node.nodes[0]
        set_var_true  = old_set_var.clone.tap {|sv_t| sv_t.value = TrueNode.new }
        set_var_false = old_set_var.clone.tap {|sv_f| sv_f.value = FalseNode.new }
        node.nodes = [
          IfNode.new(binary_op, Nodes.new([
            set_var_true, ElseNode.new(Nodes.new([
            set_var_false
            ]))
          ]))
        ]
      end
    end
  end
end
