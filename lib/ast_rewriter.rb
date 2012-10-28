require File.expand_path("../constants", __FILE__)
require File.expand_path("../class_map", __FILE__)
require File.expand_path("../walker", __FILE__)

module Riml
  class AST_Rewriter
    include Riml::Constants

    attr_reader :ast
    def initialize(ast)
      @ast = ast
    end

    # Map of {"ClassName" => ClassDefinitionNode}
    # Can also query object for superclass of a named class, etc...
    #
    # Ex : classes["SomeClass"].superclass_name => "SomeClassBase"
    def classes
      @@classes ||= ClassMap.new
    end

    def rewrite
      establish_parents(ast)
      StrictEqualsComparisonOperator.new(ast).rewrite_on_match
      VarEqualsComparisonOperator.new(ast).rewrite_on_match
      ClassDefinitionToFunctions.new(ast).rewrite_on_match
      ObjectInstantiationToCall.new(ast).rewrite_on_match
      CallToExplicitCall.new(ast).rewrite_on_match
      ast
    end

    def establish_parents(node)
      Walker.walk_node(node, method(:do_establish_parents))
    end
    alias reestablish_parents establish_parents

    def do_establish_parents(node)
      node.children.each do |child|
        child.parent_node = node if child.respond_to?(:parent_node=)
      end if node.respond_to?(:children)
    end

    def rewrite_on_match(node = ast)
      Walker.walk_node(node, method(:do_rewrite_on_match), lambda {|_| repeatable?})
    end

    def do_rewrite_on_match(node)
      replace node if match?(node)
    end

    def repeatable?
      true
    end

    class StrictEqualsComparisonOperator < AST_Rewriter
      def match?(node)
        BinaryOperatorNode === node && node.operator == '==='
      end

      def replace(node)
        node.operator = '=='
        node.operand1 = ListNode.wrap(node.operand1)
        node.operand2 = ListNode.wrap(node.operand2)
        reestablish_parents(node)
      end
    end

    class VarEqualsComparisonOperator < AST_Rewriter
      COMPARISON_OPERATOR_MATCH = Regexp.union(COMPARISON_OPERATORS)

      def match?(node)
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
        reestablish_parents(node)
      end
    end

    class ClassDefinitionToFunctions < AST_Rewriter
      def match?(node)
        ClassDefinitionNode === node
      end

      def replace(node)
        classes[node.name] = node

        name, expressions = node.name, node.expressions
        InsertInitializeMethod.new(node).rewrite_on_match
        constructor = node.constructor
        constructor.scope_modifier = 'g:' unless constructor.scope_modifier
        constructor.name = node.constructor_name
        # set up dictionary variable at top of function
        dict_name = node.constructor_obj_name
        constructor.expressions.unshift(
          SetVariableNode.new(nil, dict_name, DictionaryNode.new({}))
        )

        SuperToObjectExtension.new(constructor, node).rewrite_on_match
        MethodToNestedFunction.new(node, constructor, dict_name).rewrite_on_match
        SelfToDictName.new(dict_name).rewrite_on_match(constructor)

        constructor.expressions.push(
          ReturnNode.new(GetVariableNode.new(nil, dict_name))
        )
        reestablish_parents(constructor)
      end

      class MethodToNestedFunction < AST_Rewriter
        attr_reader :constructor, :dict_name
        def initialize(class_node, constructor, dict_name)
          super(class_node)
          @dict_name, @constructor = dict_name, constructor
        end

        def match?(node)
          DefMethodNode === node
        end

        def replace(node)
          def_node = node.to_def_node
          node.parent_node = ast.expressions
          node.remove
          def_node.name.insert(0, "#{dict_name}.")
          def_node.parent_node = constructor.expressions
          constructor.expressions << def_node
          reestablish_parents(node)
        end
      end

      class SelfToDictName < AST_Rewriter
        attr_reader :dict_name
        def initialize(dict_name)
          @dict_name = dict_name
        end

        def match?(node)
          DictSetDotNode === node && node.dict.name == "self"
        end

        def replace(node)
          node.dict.name = dict_name
        end
      end

      class InsertInitializeMethod < AST_Rewriter
        # if doesn't have an initialize method, put one at the beginning
        # of the class definition
        def match?(class_node)
          ClassDefinitionNode === class_node && class_node.constructor.nil?
        end

        def replace(class_node)
          if class_node.superclass?
            def_node = DefNode.new(
              '!', nil, "initialize", superclass_params, nil, Nodes.new([SuperNode.new([], false)])
            )
          else
            def_node = DefNode.new(
              '!', nil, "initialize", [], nil, Nodes.new([])
            )
          end
          class_node.expressions.unshift(def_node)
          reestablish_parents(class_node)
        end

        def superclass_params
          classes.superclass(ast.name).constructor.parameters
        end

        def repeatable?
          false
        end
      end

      class SuperToObjectExtension < AST_Rewriter
        attr_reader :class_node
        def initialize(constructor, class_node)
          super(constructor)
          @class_node = class_node
        end

        def match?(constructor)
          DefNode === constructor && constructor.super_node
        end

        def replace(constructor)
          superclass = classes.superclass(class_node.name)
          super_constructor = superclass.constructor

          set_var_node = SetVariableNode.new(nil, superclass.constructor_obj_name,
            CallNode.new(
              super_constructor.scope_modifier,
              super_constructor.name,
              super_arguments(constructor.super_node)
            )
          )

          constructor.super_node.replace_with(set_var_node)
          constructor.expressions.insert_after(set_var_node,
            ExplicitCallNode.new(
              nil,
              "extend",
              [
                GetVariableNode.new(nil, class_node.constructor_obj_name),
                GetVariableNode.new(nil, superclass.constructor_obj_name)
              ]
            )
          )
          reestablish_parents(constructor)
        end

        def super_arguments(super_node)
          if super_node.use_all_arguments?
            # here, ast is 'constructor'
            ast.parameters.map {|p| GetVariableNode.new(nil, p)}
          else
            super_node.arguments
          end
        end

        def repeatable?
          false
        end
      end
    end # ClassDefinitionToFunctions

    class ObjectInstantiationToCall < AST_Rewriter
      def match?(node)
        ObjectInstantiationNode === node
      end

      def replace(node)
        constructor_name = node.call_node.name
        class_node = classes[constructor_name]
        call_node = node.call_node
        call_node.name = class_node.constructor_name
        call_node.scope_modifier = class_node.constructor.scope_modifier
      end
    end

    class CallToExplicitCall < AST_Rewriter
      def match?(node)
        node.instance_of?(CallNode) && node.must_be_explicit_call?
      end

      def replace(node)
        node.replace_with(ExplicitCallNode.new(node[0], node[1], node[2]))
        reestablish_parents(node)
      end
    end

  end
end
