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
      ClassDefinitionToFunctions.new(ast).rewrite_on_match
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

    class ClassDefinitionToFunctions < AST_Rewriter
      def match(node)
        ClassDefinitionNode === node
      end

      def replace(node)
        name, expressions = node.name, node.expressions
        constructor = expressions.detect {|e| DefNode === e && e.name == 'initialize'}
        constructor.scope_modifier = 'g:' unless constructor.scope_modifier
        constructor.name = "#{name}Constructor"
        # set up dictionary variable at top of function
        dict_name = name[0].downcase + name[1..-1] + "Obj"
        constructor.expressions.unshift(
          SetVariableNode.new(nil, dict_name, DictionaryNode.new({}))
        )

        MethodToNestedFunction.new(node, constructor, dict_name).rewrite_on_match
        SelfToDictName.new(dict_name).rewrite_on_match(constructor)

        constructor.expressions.push(
          ReturnNode.new(GetVariableNode.new(nil, dict_name))
        )
      end

      class MethodToNestedFunction < AST_Rewriter
        attr_reader :constructor, :dict_name
        def initialize(class_node, constructor, dict_name)
          super(class_node)
          @dict_name, @constructor = dict_name, constructor
        end

        def match(node)
          DefMethodNode === node
        end

        def replace(node)
          def_node = node.to_def_node
          node.parent_node = ast.expressions
          node.remove
          def_node.name.insert(0, "#{dict_name}.")
          constructor.expressions << def_node
        end
      end

      class SelfToDictName < AST_Rewriter
        attr_reader :dict_name
        def initialize(dict_name)
          @dict_name = dict_name
        end

        def match(node)
          DictSetNode === node && node.dict.name == "self"
        end

        def replace(node)
          node.dict.name = dict_name
        end
      end
    end

  end
end
