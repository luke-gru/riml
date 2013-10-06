require File.expand_path("../constants", __FILE__)
require File.expand_path("../imported_class", __FILE__)
require File.expand_path("../class_map", __FILE__)
require File.expand_path("../walker", __FILE__)

module Riml
  class AST_Rewriter
    include Riml::Constants

    attr_accessor :ast
    attr_reader   :classes, :rewritten_included_and_sourced_files

    def initialize(ast = nil, classes = nil)
      @ast = ast
      @classes = classes || ClassMap.new
      # Keeps track of filenames with their rewritten ASTs, to prevent rewriting
      # the same AST more than once.
      @rewritten_included_and_sourced_files = {}
      # Keeps track of which filenames included/sourced which.
      # ex: { nil => ["main.riml"], "main.riml" => ["lib1.riml", "lib2.riml"],
      # "lib1.riml" => [], "lib2.riml" => [] }
      @included_and_sourced_file_refs = Hash.new { |h, k| h[k] = [] }
    end

    def rewrite(filename = nil, included = false)
      if filename && (rewritten_ast = rewritten_included_and_sourced_files[filename])
        return rewritten_ast
      end
      establish_parents(ast)
      class_imports  = RegisterImportedClasses.new(ast, classes)
      class_imports.rewrite_on_match
      class_registry = RegisterDefinedClasses.new(ast, classes)
      class_registry.rewrite_on_match
      rewrite_included_and_sourced_files!(filename)
      if filename && !included && add_SID_function?(filename)
        add_SID_function!
      end
      rewriters = [
        StrictEqualsComparisonOperator.new(ast, classes),
        VarEqualsComparisonOperator.new(ast, classes),
        ClassDefinitionToFunctions.new(ast, classes),
        ObjectInstantiationToCall.new(ast, classes),
        CallToExplicitCall.new(ast, classes),
        DefaultParamToIfNode.new(ast, classes),
        DeserializeVarAssignment.new(ast, classes),
        TopLevelDefMethodToDef.new(ast, classes)
      ]
      rewriters.each do |rewriter|
        rewriter.rewrite_on_match
      end
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
      Walker.walk_node(node, method(:do_rewrite_on_match), lambda { |_| recursive? })
    end

    def do_rewrite_on_match(node)
      replace node if match?(node)
    end

    # We need to rewrite the included/sourced files before anything else. This is in
    # order to keep track of any classes defined in the included and sourced files (and
    # files included/sourced in those, etc...). We keep a cache of rewritten asts
    # because the included/sourced files are parsed more than once. They're parsed
    # first in this step, plus whenever the compiler visits a 'riml_include'/'riml_source'
    # node in order to compile it on the spot.
    def rewrite_included_and_sourced_files!(filename)
      old_ast = ast
      ast.children.each do |node|
        next unless RimlFileCommandNode === node
        action = node.name == 'riml_include' ? 'include' : 'source'

        node.each_existing_file! do |file, fullpath|
          if filename && @included_and_sourced_file_refs[file].include?(filename)
            msg = "#{filename.inspect} can't #{action} #{file.inspect}, as " \
                  " #{file.inspect} already included/sourced #{filename.inspect}"
            # IncludeFileLoop/SourceFileLoop
            raise Riml.const_get("#{action.capitalize}FileLoop"), msg
          elsif filename == file
            raise UserArgumentError, "#{file.inspect} can't include itself"
          end
          @included_and_sourced_file_refs[filename] << file
          riml_src = File.read(fullpath)
          # recursively parse included files with this ast_rewriter in order
          # to pick up any classes that are defined there
          rewritten_ast = Parser.new.parse(riml_src, self, file, action == 'include')
          rewritten_included_and_sourced_files[file] = rewritten_ast
        end
      end
    ensure
      self.ast = old_ast
    end

    def recursive?
      true
    end

    # Add SID function if this is the main file and it has defined classes, or
    # if it included other files and any one of those other files defined classes.
    def add_SID_function?(filename)
      return true if ast.children.grep(ClassDefinitionNode).any?
      included_files = @included_and_sourced_file_refs[filename]
      while included_files.any?
        incs = []
        included_files.each do |included_file|
          if (ast = rewritten_included_and_sourced_files[included_file])
            return true if ast.children.grep(ClassDefinitionNode).any?
          end
          incs.concat @included_and_sourced_file_refs[included_file]
        end
        included_files = incs
      end
      false
    end

    # :h <SID>
    def add_SID_function!
      fchild = ast.nodes.first
      return false if DefNode === fchild && fchild.name == 'SID' && fchild.scope_modifier == 's:'
      fn = DefNode.new('!', nil, 's:', 'SID', [], nil, Nodes.new([
          ReturnNode.new(CallNode.new(nil, 'matchstr', [
            CallNode.new(nil, 'expand', [StringNode.new('<sfile>', :s)]),
            StringNode.new('<SNR>\zs\d\+\ze_SID$', :s)
          ]
          ))
        ])
      )
      fn.parent = ast.nodes
      establish_parents(fn)
      ast.nodes.unshift fn
    end

    class RegisterImportedClasses < AST_Rewriter
      def match?(node)
        RimlClassCommandNode === node
      end

      def replace(node)
        node.class_names_without_modifiers.each do |class_name|
          # TODO: check for wrong scope modifier
          imported_class = ImportedClass.new(class_name)
          imported_class.instance_variable_set("@registered_state", true)
          classes["g:#{class_name}"] = imported_class
        end
        node.remove
      end
    end

    class RegisterDefinedClasses < AST_Rewriter
      def match?(node)
        ClassDefinitionNode === node
      end

      def replace(node)
        n = node.dup
        n.instance_variable_set("@registered_state", true)
        classes[node.full_name] = n
      end
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
        AssignNode === node.nodes[0] &&
        BinaryOperatorNode === (op = node.nodes[0].rhs) &&
        op.operator =~ COMPARISON_OPERATOR_MATCH
      end

      def replace(node)
        binary_op = node.nodes[0].rhs
        old_set_var = node.nodes[0]
        assign_true  = old_set_var.dup.tap {|assign_t| assign_t.rhs = TrueNode.new}
        assign_false = old_set_var.dup.tap {|assign_f| assign_f.rhs = FalseNode.new}
        node.nodes = [
          IfNode.new(binary_op, Nodes.new([
            assign_true, ElseNode.new(Nodes.new([
            assign_false
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
        classes[node.full_name] = node

        RegisterPrivateFunctions.new(node, classes).rewrite_on_match
        DefNodeToPrivateFunction.new(node, classes).rewrite_on_match
        InsertInitializeMethod.new(node, classes).rewrite_on_match
        constructor = node.constructor
        constructor.name = node.constructor_name
        constructor.original_name = 'initialize'
        constructor.scope_modifier = node.scope_modifier
        # set up dictionary variable at top of function
        dict_name = node.constructor_obj_name
        constructor.expressions.unshift(
          AssignNode.new('=', GetVariableNode.new(nil, dict_name), DictionaryNode.new({}))
        )

        InitializeSuperToObjectExtension.new(constructor, classes, node).rewrite_on_match
        ExtendObjectWithMethods.new(node, classes).rewrite_on_match
        SelfToDictName.new(dict_name).rewrite_on_match(constructor)
        SuperToSuperclassFunction.new(node, classes).rewrite_on_match
        PrivateFunctionCallToPassObjExplicitly.new(node, classes).rewrite_on_match

        constructor.expressions.push(
          ReturnNode.new(GetVariableNode.new(nil, dict_name))
        )
        reestablish_parents(constructor)
      end

      class RegisterPrivateFunctions < AST_Rewriter
        def match?(node)
          node.instance_of?(DefNode) && node.name != 'initialize'
        end

        def replace(node)
          ast.private_function_names << node.name
        end
      end

      class SelfToObjArgumentInPrivateFunction < AST_Rewriter
        def initialize(ast, classes, class_node)
          super(ast, classes)
          @class_node = class_node
        end

        def match?(node)
          return unless GetVariableNode === node && node.scope_modifier == nil && node.name == 'self'
          return if node.parent.is_a?(DictGetDotNode) && node.parent.parent.is_a?(CallNode) &&
            (@class_node.private_function_names & node.parent.keys).size == 1
          # make sure we're not nested in a different function
          n = node
          until n.instance_of?(DefNode)
            n = n.parent
          end
          n == ast
        end

        def replace(node)
          node.name = @class_node.constructor_obj_name
          node.scope_modifier = 'a:'
        end
      end

      class DefNodeToPrivateFunction < AST_Rewriter
        def match?(node)
          return unless node.instance_of?(DefNode) && node.name != 'initialize'
          node.private_function = true
        end

        def replace(node)
          class_node = ast
          class_name = class_node.name
          node.scope_modifier = 's:'
          node.name = "#{class_name}_#{node.name}"
          node.sid = nil
          node.keywords -= ['dict']
          node.parameters.unshift(class_node.constructor_obj_name)
          # rewrite `self` in function body to a:#{class_name}Obj
          self_to_obj_argument = SelfToObjArgumentInPrivateFunction.new(node, classes, class_node)
          self_to_obj_argument.rewrite_on_match
          reestablish_parents(node)
        end
      end

      class PrivateFunctionCallToPassObjExplicitly < AST_Rewriter
        def match?(node)
          CallNode === node && DictGetDotNode === node.name && node.name.dict.scope_modifier.nil? &&
            node.name.dict.name == 'self' && (node.name.keys & ast.private_function_names).size == 1
        end

        def replace(node)
          node.scope_modifier = 's:'
          # find function that I'm in
          n = node
          until n.instance_of?(DefNode)
            n = n.parent
          end
          if n.original_name == 'initialize'
            node.arguments.unshift(GetVariableNode.new(nil, ast.constructor_obj_name))
          elsif n.private_function
            node.arguments.unshift(GetVariableNode.new('a:', ast.constructor_obj_name))
          else
            node.arguments.unshift(GetVariableNode.new(nil, 'self'))
          end
          func_name = node.name.keys.first
          node.name = "#{ast.name}_#{func_name}"
          reestablish_parents(node)
        end
      end

      class ExtendObjectWithMethods < AST_Rewriter
        def match?(node)
          DefMethodNode === node
        end

        def replace(node)
          def_node = node.to_def_node
          class_expressions = ast.expressions
          class_expressions.insert_after(class_expressions.last, def_node)
          def_node.parent = class_expressions
          # to remove it
          node.parent = class_expressions
          node.remove
          def_node.original_name = def_node.name.dup
          def_node.name.insert(0, "#{ast.name}_")
          def_node.sid = SIDNode.new
          reestablish_parents(def_node)
          extend_obj_with_methods(def_node)
        end

        # Ex: `let dogObj.bark = function('<SNR>' . s:SID() . '_s:Dog_bark')`
        def extend_obj_with_methods(def_node)
          constructor = ast.constructor
          extension =
            AssignNode.new('=',
              DictGetDotNode.new(
                GetVariableNode.new(nil, ast.constructor_obj_name),
                [def_node.original_name]
              ),
              CallNode.new(
                nil, 'function', [
                  BinaryOperatorNode.new(
                    '.',
                    [
                      BinaryOperatorNode.new(
                        '.',
                        [
                          StringNode.new('<SNR>', :s),
                          CallNode.new('s:', 'SID', []),
                        ]
                      ),
                      StringNode.new("_s:#{def_node.name}", :s)
                    ],
                  )
                ],
              )
            )
          constructor.expressions << extension
          extension.parent = constructor.expressions
        end
      end

      class SelfToDictName < AST_Rewriter
        attr_reader :dict_name
        def initialize(dict_name)
          @dict_name = dict_name
        end

        def match?(node)
          AssignNode === node && DictGetNode === node.lhs && node.lhs.dict.name == "self"
        end

        def replace(node)
          node.lhs.dict.name = dict_name
        end
      end

      class InsertInitializeMethod < AST_Rewriter
        # if doesn't have an initialize method, put one at the beginning
        # of the class definition
        def match?(class_node)
          ClassDefinitionNode === class_node && class_node.constructor.nil?
        end

        def replace(class_node)
          if class_node.superclass? && !imported_superclass?
            def_node = DefNode.new(
              '!', nil, nil, "initialize", superclass_params, nil, Nodes.new([SuperNode.new([], false)])
            )
          # has imported superclass and no initialize method. Must create
          # initialize method taking *splat parameter and call super it
          elsif class_node.superclass?
            def_node = DefNode.new(
              '!', nil, nil, "initialize", ['...'], nil, Nodes.new([SuperNode.new([], false)])
            )
          else
            def_node = DefNode.new(
              '!', nil, nil, "initialize", [], nil, Nodes.new([])
            )
          end
          class_node.expressions.unshift(def_node)
          reestablish_parents(class_node)
        end

        def superclass_params
          classes.superclass(ast.full_name).constructor.parameters
        end

        def imported_superclass?
          classes.superclass(ast.full_name).imported?
        end

        def recursive?
          false
        end
      end

      class InitializeSuperToObjectExtension < AST_Rewriter
        attr_reader :class_node
        def initialize(constructor, classes, class_node)
          super(constructor, classes)
          @class_node = class_node
        end

        def match?(constructor)
          DefNode === constructor && constructor.super_node
        end

        def replace(constructor)
          unless class_node.superclass?
            # TODO: raise error instead of aborting
            abort "class #{class_node.full_name.inspect} called super in its " \
              " initialize function, but it has no superclass."
          end

          superclass = classes.superclass(class_node.full_name)
          super_constructor = superclass.constructor

          set_var_node = AssignNode.new('=', GetVariableNode.new(nil, superclass.constructor_obj_name),
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

        def recursive?
          false
        end
      end

      # rewrites calls to 'super' in non-initialize function
      class SuperToSuperclassFunction < AST_Rewriter
        def match?(node)
          return false unless SuperNode === node
          n = node
          n = n.parent until DefNode === n || n.nil?
          return false if n.nil? || ast.constructor == n
          @function_node = n
        end

        def replace(node)
          # TODO: check if class even has superclass before all this
          func_scope = 's:'
          superclass = classes[ast.superclass_full_name]
          while superclass && !superclass.has_function?(func_scope, superclass_func_name(superclass)) && superclass.superclass?
            superclass = classes[superclass.superclass_full_name]
          end
          if superclass.nil? || !superclass.has_function?(func_scope, superclass_func_name(superclass))
            raise Riml::UserFunctionNotFoundError,
              "super was called in class #{ast.full_name} in " \
              "function #{@function_node.original_name}, but there are no " \
              "functions with this name in that class's superclass hierarchy."
          end
          call_node = CallNode.new(
            nil,
            DictGetDotNode.new(
              GetVariableNode.new(nil, 'self'),
              [superclass_func_name(superclass)]
            ),
            node.arguments
          )

          node.replace_with(call_node)
          add_superclass_func_ref_to_constructor(superclass)
          reestablish_parents(@function_node)
        end

        def superclass_func_name(superclass)
          "#{superclass.name}_#{@function_node.original_name}"
        end

        def add_superclass_func_ref_to_constructor(superclass)
          super_func_name = superclass_func_name(superclass)
          assign_node = AssignNode.new('=',
            DictGetDotNode.new(
              GetVariableNode.new(nil, ast.constructor_obj_name),
              [super_func_name]
            ),
            CallNode.new(
              nil, 'function', [
                BinaryOperatorNode.new(
                  '.',
                  [
                    BinaryOperatorNode.new(
                      '.',
                      [
                        StringNode.new('<SNR>', :s),
                        CallNode.new('s:', 'SID', []),
                      ]
                    ),
                    StringNode.new("_s:#{super_func_name}", :s)
                  ],
                )
              ],
            )
          )
          ast.constructor.expressions << assign_node
          reestablish_parents(ast.constructor)
        end
      end
    end # ClassDefinitionToFunctions

    class ObjectInstantiationToCall < AST_Rewriter
      def match?(node)
        ObjectInstantiationNode === node
      end

      def replace(node)
        constructor_name = (node.call_node.scope_modifier ||
                            ClassDefinitionNode::DEFAULT_SCOPE_MODIFIER) +
                            node.call_node.name
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
        explicit = node.replace_with(ExplicitCallNode.new(node[0], node[1], node[2]))
        reestablish_parents(explicit)
      end
    end

    class DefaultParamToIfNode < AST_Rewriter
      def match?(node)
        DefaultParamNode === node
      end

      def replace(node)
        def_node = node.parent
        param_idx = def_node.parameters.index(node)
        first_default_param = def_node.parameters.detect(&DefNode::DEFAULT_PARAMS)
        first_default_param_idx = def_node.parameters.index(first_default_param)

        last_default_param = def_node.parameters.reverse.detect(&DefNode::DEFAULT_PARAMS)
        insert_idx = param_idx - first_default_param_idx

        while param = def_node.parameters[param_idx += 1]
          unless param == def_node.splat || DefaultParamNode === param
            raise UserArgumentError, "can't have regular parameter after default parameter in function #{def_node.name.inspect}"
          end
        end

        if_expression = construct_if_expression(node)

        if last_default_param == node
          def_node.parameters.delete_if(&DefNode::DEFAULT_PARAMS)
          def_node.parameters << SPLAT_LITERAL unless def_node.splat
        end
        def_node.expressions.insert(insert_idx, if_expression)
        reestablish_parents(def_node)
      end

      def construct_if_expression(node)
        get_splat_node = CallNode.new(nil, 'get', [ GetVariableNode.new('a:', '000'), NumberNode.new(0), StringNode.new('rimldefault', :s) ])
        condition_node = BinaryOperatorNode.new('!=#', [ get_splat_node, StringNode.new('rimldefault', :s) ])
        remove_from_splat_node = CallNode.new(nil, 'remove', [ GetVariableNode.new('a:', '000'), NumberNode.new(0) ])
        IfNode.new(condition_node,
          Nodes.new([
            AssignNode.new('=', GetVariableNode.new(nil, node.parameter), remove_from_splat_node),
          ElseNode.new(Nodes.new([
            AssignNode.new('=', GetVariableNode.new(nil, node.parameter), node.expression)
          ]))
          ])
        )
      end
    end

    class DeserializeVarAssignment < AST_Rewriter
      def match?(node)
        AssignNode === node && AssignNode === node.rhs && node.operator == '='
      end

      def replace(node)
        orig_assign = node.dup
        assigns = []
        while assign_node = (node.respond_to?(:rhs) && node.rhs)
          assigns.unshift([node.lhs, node.rhs])
          node = assign_node
        end
        assigns = assigns[0..0].concat(assigns[1..-1].map! { |(lhs, rhs)| [lhs, rhs.lhs] })

        assigns.map! do |(lhs, rhs)|
          AssignNode.new('=', lhs, rhs)
        end

        new_assigns = Nodes.new(assigns)
        new_assigns.parent = orig_assign.parent
        orig_assign.replace_with(new_assigns)
        establish_parents(new_assigns)
      end
    end

    class TopLevelDefMethodToDef < AST_Rewriter
      def match?(node)
        DefMethodNode === node
      end

      def replace(node)
        Riml.warn "top-level function #{node.full_name} is defined with 'defm', which " \
          "should only be used inside classes. Please use 'def'"
        scope_modifier = node.scope_modifier
        keywords = node.keywords
        new_node = node.to_def_node
        new_node.scope_modifier = scope_modifier
        new_node.keywords = keywords
        node.replace_with(new_node)
      end
    end

  end
end
