require File.expand_path("../constants", __FILE__)
require File.expand_path("../imported_class", __FILE__)
require File.expand_path("../class_map", __FILE__)
require File.expand_path("../class_dependency_graph", __FILE__)
require File.expand_path("../walker", __FILE__)

module Riml
  class AST_Rewriter
    include Riml::Constants

    attr_accessor :ast, :options
    attr_reader :classes

    def initialize(ast = nil, classes = nil, class_dependency_graph = nil)
      @ast = ast
      @classes = classes || ClassMap.new
      # AST_Rewriter shares options with Parser. Parser set AST_Rewriter's
      # options before call to `rewrite`.
      @options = nil
      # Keeps track of filenames with their rewritten ASTs, to prevent rewriting
      # the same AST more than once.
      @rewritten_included_and_sourced_files = {}
      # Keeps track of which filenames included/sourced which.
      # ex: { nil => ["main.riml"], "main.riml" => ["lib1.riml", "lib2.riml"],
      # "lib1.riml" => [], "lib2.riml" => [] }
      @included_and_sourced_file_refs = Hash.new { |h, k| h[k] = [] }
      @class_dependency_graph = class_dependency_graph || ClassDependencyGraph.new
      @resolving_class_dependencies = nil
    end

    def rewrite(filename = nil, included = false)
      if filename && (rewritten_ast = Riml.rewritten_ast_cache[filename])
        return rewritten_ast
      end

      establish_parents(ast)
      if @options && @options[:allow_undefined_global_classes] && !@classes.has_global_import?
        @classes.globbed_imports.unshift(ImportedClass.new('*'))
      end
      class_imports = RegisterImportedClasses.new(ast, classes)
      class_imports.rewrite_on_match
      if resolve_class_dependencies?
        resolve_class_dependencies!(filename)
        return if @resolving_class_dependencies == true
      end
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
      Walker.walk_node(node, method(:do_rewrite_on_match), max_recursion_lvl)
    end

    def do_rewrite_on_match(node)
      replace node if match?(node)
    end

    def resolve_class_dependencies?
      @resolving_class_dependencies = false if @options[:include_reordering] != true
      @resolving_class_dependencies != false
    end

    def resolve_class_dependencies!(filename)
      if @resolving_class_dependencies.nil?
        start_resolving = @resolving_class_dependencies = true
        @included_ASTs_by_include_file = {}
      end
      old_ast = ast
      RegisterClassDependencies.new(ast, classes, @class_dependency_graph, filename).rewrite_on_match
      ast.children.grep(RimlFileCommandNode).each do |node|
        next unless node.name == 'riml_include'
        node.each_existing_file! do |file, fullpath|
          if filename && @included_and_sourced_file_refs[file].include?(filename)
            msg = "#{filename.inspect} can't include #{file.inspect}, as " \
                  " #{file.inspect} already included #{filename.inspect}"
            error = IncludeFileLoop.new(msg, node)
            raise error
          elsif filename == file
            error = UserArgumentError.new("#{file.inspect} can't include itself", node)
            raise error
          end
          @included_and_sourced_file_refs[filename] << file
          riml_src = File.read(fullpath)
          Parser.new.tap { |p| p.options = @options }.parse(riml_src, self, file, true)
          @included_ASTs_by_include_file[file] = Parser.ast_cache[file]
        end
      end
    ensure
      self.ast = old_ast
      if start_resolving == true
        @resolving_class_dependencies = false
        @included_and_sourced_file_refs.clear
        reorder_includes_based_on_class_dependencies!
      end
    end

    def reorder_includes_based_on_class_dependencies!
      global_included_filename_order = @class_dependency_graph.filename_order
      asts = [ast]
      while (ast = asts.shift)
        include_nodes =
          ast.children.grep(RimlFileCommandNode).select do |n|
            n.name == 'riml_include'
          end
        included_filenames = include_nodes.map { |n| n.arguments.map(&:value) }.flatten
        new_order_filenames = global_included_filename_order & included_filenames
        add_to_head = included_filenames - new_order_filenames
        new_order_filenames = add_to_head + new_order_filenames
        include_nodes.each do |node|
          node.arguments.each do |arg|
            if (included_file_ast = @included_ASTs_by_include_file[arg.value])
              asts << included_file_ast
            end
            if new_order_filenames.first
              arg.value = new_order_filenames.shift
            else
              # for now, just to be cautious
              raise "Internal error in AST rewriting process. Please report bug!"
            end
          end
        end
      end
    end

    class RegisterClassDependencies < AST_Rewriter
      def initialize(ast, classes, class_dependency_graph, filename)
        super(ast, classes, class_dependency_graph)
        @filename = filename
      end

      def match?(node)
        ClassDefinitionNode === node || ObjectInstantiationNode === node
      end

      def replace(node)
        if ClassDefinitionNode === node
          @class_dependency_graph.class_defined(
            @filename, class_node_full_name(node),
            class_name_full_name(node.superclass_name)
          )
        else
          @class_dependency_graph.class_encountered(
            @filename,
            class_node_full_name(node.call_node)
          )
        end
      end

      private

      def class_node_full_name(node)
        (
         node.scope_modifier ||
         ClassDefinitionNode::DEFAULT_SCOPE_MODIFIER
        ) + node.name
      end

      def class_name_full_name(class_name)
        return nil if class_name.nil?
        if class_name[1, 1] == ':'
          class_name
        else
          ClassDefinitionNode::DEFAULT_SCOPE_MODIFIER + class_name
        end
      end
    end

    # We need to rewrite the included/sourced files before anything else. This is in
    # order to keep track of any classes defined in the included and sourced files (and
    # files included/sourced in those, etc...). We keep a cache of rewritten asts
    # because the included/sourced files are parsed more than once. They're parsed
    # first in this step, plus whenever the compiler visits a 'riml_include'/'riml_source'
    # node in order to compile it on the spot.
    def rewrite_included_and_sourced_files!(filename)
      old_ast = ast
      ast.children.grep(RimlFileCommandNode).each do |node|
        action = node.name == 'riml_include' ? 'include' : 'source'

        node.each_existing_file! do |file, fullpath|
          if filename && @included_and_sourced_file_refs[file].include?(filename)
            msg = "#{filename.inspect} can't #{action} #{file.inspect}, as " \
                  " #{file.inspect} already included/sourced #{filename.inspect}"
            # IncludeFileLoop/SourceFileLoop
            error = Riml.const_get("#{action.capitalize}FileLoop").new(msg, node)
            raise error
          elsif filename == file
            error = UserArgumentError.new("#{file.inspect} can't #{action} itself", node)
            raise error
          end
          @included_and_sourced_file_refs[filename] << file
          # recursively parse included files with this ast_rewriter in order
          # to pick up any classes that are defined there
          rewritten_ast = nil
          watch_for_class_pickup do
            rewritten_ast = Riml.rewritten_ast_cache.fetch(file) do
              riml_src = File.read(fullpath)
              Parser.new.tap { |p| p.options = @options }.
                parse(riml_src, self, file, action == 'include')
            end
          end
          @rewritten_included_and_sourced_files[file] ||= rewritten_ast
        end
      end
    ensure
      self.ast = old_ast
    end

    def watch_for_class_pickup
      before_class_names = @classes.class_names
      ast = yield
      after_class_names = @classes.class_names
      diff_class_names = after_class_names - before_class_names
      class_diff = diff_class_names.inject({}) do |hash, class_name|
        hash[class_name] = @classes[class_name]
        hash
      end
      # no classes were picked up, it could be that the cache was hit. Let's
      # register the cached classes for this ast, if there are any
      if class_diff.empty?
        real_diff = Riml.rewritten_ast_cache.fetch_classes_registered(ast)
        real_diff.each do |k,v|
          @classes[k] = v unless @classes.safe_fetch(k)
        end
      # new classes were picked up, let's save them with this ast as the key
      else
        Riml.rewritten_ast_cache.save_classes_registered(ast, class_diff)
      end
    end

    # recurse until no more children
    def max_recursion_lvl
      -1
    end

    # Add SID function if this is the main file and it has defined classes, or
    # if it included other files and any one of those other files defined classes.
    def add_SID_function?(filename)
      return true if ast.children.grep(ClassDefinitionNode).any?
      included_files = @included_and_sourced_file_refs[filename]
      while included_files.any?
        incs = []
        included_files.each do |included_file|
          if (ast = @rewritten_included_and_sourced_files[included_file])
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
          IfNode.new(
            CallNode.new(nil, 'exists', [StringNode.new('s:SID_VALUE', :s)]),
            Nodes.new([
              ReturnNode.new(GetVariableNode.new('s:', 'SID_VALUE'))
            ])
          ),
          AssignNode.new(
            '=',
            GetVariableNode.new('s:', 'SID_VALUE'),
            CallNode.new(nil, 'matchstr', [
            CallNode.new(nil, 'expand', [StringNode.new('<sfile>', :s)]),
            StringNode.new('<SNR>\zs\d\+\ze_SID$', :s)
          ]
          )),
          ReturnNode.new(GetVariableNode.new('s:', 'SID_VALUE'))
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
          if imported_class.globbed?
            classes.globbed_imports << imported_class
          else
            imported_class.instance_variable_set("@registered_state", true)
            classes["g:#{class_name}"] = imported_class
          end
        end
        node.remove
      end

      def max_recursion_lvl
        1
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

      def max_recursion_lvl
        1
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

        RegisterPrivateFunctions.new(node.expressions, classes).rewrite_on_match
        DefNodeToPrivateFunction.new(node.expressions, classes).rewrite_on_match
        InsertInitializeMethod.new(node, classes).rewrite_on_match
        constructor = node.constructor
        constructor.name = node.constructor_name
        constructor.original_name = 'initialize'
        constructor.scope_modifier = node.scope_modifier
        # set up dictionary variable at top of function
        dict_name = node.constructor_obj_name
        constructor.expressions.nodes.unshift(
          AssignNode.new('=', GetVariableNode.new(nil, dict_name), DictionaryNode.new({}))
        )

        InitializeSuperToObjectExtension.new(constructor, classes, node).rewrite_on_match
        ExtendObjectWithMethods.new(node, classes).rewrite_on_match
        SelfToDictName.new(dict_name).rewrite_on_match(constructor)
        SuperToSuperclassFunction.new(node, classes).rewrite_on_match
        PrivateFunctionCallToPassObjExplicitly.new(node, classes).rewrite_on_match
        SplatsToExecuteInCallingContext.new(node, classes).rewrite_on_match

        constructor.expressions.nodes.push(
          ReturnNode.new(GetVariableNode.new(nil, dict_name))
        )
        reestablish_parents(constructor)
      end

      def max_recursion_lvl
        1
      end

      class RegisterPrivateFunctions < AST_Rewriter
        def match?(node)
          node.instance_of?(DefNode) && node.name != 'initialize'
        end

        def replace(node)
          ast.parent.private_function_names << node.name
        end

        def max_recursion_lvl
          1
        end
      end

      # Rewrite constructs like:
      #
      #   let animalObj = s:AnimalConstructor(*a:000)
      #
      # to:
      #
      #   let __riml_splat_list = a:000
      #   let __riml_splat_size = len(__riml_splat_list)
      #   let __riml_splat_str_vars = []
      #   let __riml_splat_idx = 1
      #   while __riml_splat_idx <=# __riml_splat_size
      #     let __riml_splat_var_{__riml_splat_idx} = get(__riml_splat_list, __riml_splat_idx - 1)
      #     call add(__riml_splat_str_vars, __riml_splat_var_{__riml_splat_idx})
      #     let __riml_splat_idx += 1
      #   endwhile
      #   execute 'let l:animalObj = s:AnimalConstructor(' . join(__riml_splat_str_vars, ', ') . ')'
      #
      # Basically, mimic Ruby's approach to expanding lists to their
      # constituent argument parts with '*' in calling context.
      # NOTE: currently only works with `super`.
      class SplatsToExecuteInCallingContext < AST_Rewriter

        def match?(node)
          if SplatNode === node && CallNode === node.parent
            @splat_node = node
          end
        end

        def replace(node)
          construct_splat_str_vars_node = build_construct_splat_str_vars_node
          call_node_args =
            CallNode.new(
              nil,
              'join',
              [
                GetVariableNode.new('n:', '__riml_splat_str_vars'),
                StringNode.new(', ', :s)
              ]
            )
          call_node = node.parent
          node_to_execute = if AssignNode === call_node.parent
            assign_node = call_node.parent
            # This is necessary because this node is getting put into a new
            # compiler where it's not wrapped in a function context, therefore
            # variables will be script-local there unless their scope_modifier
            # is set
            assign_node.lhs.scope_modifier = 'l:'
            assign_node
          else
            call_node
          end
          call_node.arguments.clear
          compiler = Compiler.new
          # have to dup node_to_execute here because, if not, its parent will
          # get reset during this next compilation step
          output = compiler.compile(Nodes.new([node_to_execute.dup]))
          execute_string_node = StringNode.new(output.chomp[0..-2], :s)
          execute_string_node.value.insert(0, 'call ') if CallNode === node_to_execute
          execute_arg = BinaryOperatorNode.new(
            '.',
            [
              execute_string_node,
              BinaryOperatorNode.new(
                '.',
                [
                  call_node_args,
                  StringNode.new(')', :s)
                ]
              )
            ]
          )
          execute_node = CallNode.new(nil, 'execute', [execute_arg])
          establish_parents(execute_node)
          node.remove
          node_to_execute.replace_with(construct_splat_str_vars_node)
          execute_node.parent = construct_splat_str_vars_node.parent
          construct_splat_str_vars_node.parent.insert_after(construct_splat_str_vars_node, execute_node)
        end

        private

        def build_construct_splat_str_vars_node
          nodes = Nodes.new([])
          splat_list_init = AssignNode.new(
            '=',
            GetVariableNode.new('n:', '__riml_splat_list'),
            splat_value
          )
          splat_size = AssignNode.new(
            '=',
            GetVariableNode.new('n:', '__riml_splat_size'),
            CallNode.new(nil, 'len', [GetVariableNode.new('n:', '__riml_splat_list')])
          )
          splat_string_vars_init = AssignNode.new(
            '=',
            GetVariableNode.new('n:', '__riml_splat_str_vars'),
            ListNode.new([])
          )
          splat_list_idx_init = AssignNode.new(
            '=',
            GetVariableNode.new('n:', '__riml_splat_idx'),
            NumberNode.new('1')
          )
          while_loop = WhileNode.new(
            # condition
            BinaryOperatorNode.new('<=', [GetVariableNode.new('n:', '__riml_splat_idx'), GetVariableNode.new('n:', '__riml_splat_size')]),
            # body
            Nodes.new([
              AssignNode.new(
                '=',
                GetCurlyBraceNameNode.new('n:', CurlyBraceVariable.new([CurlyBracePart.new('__riml_splat_var_'), CurlyBraceVariable.new([CurlyBracePart.new(GetVariableNode.new('n:', '__riml_splat_idx'))])])),
                CallNode.new(nil, 'get', [
                  GetVariableNode.new('n:', '__riml_splat_list'),
                  BinaryOperatorNode.new('-', [
                    GetVariableNode.new('n:', '__riml_splat_idx'),
                    NumberNode.new('1')
                  ])
                ])
              ),
              ExplicitCallNode.new(nil, 'add', [
                GetVariableNode.new('n:', '__riml_splat_str_vars'),
                BinaryOperatorNode.new('.', [StringNode.new('__riml_splat_var_', :s), GetVariableNode.new('n:', '__riml_splat_idx')])
              ]),
              AssignNode.new('+=', GetVariableNode.new('n:', '__riml_splat_idx'), NumberNode.new('1'))
            ])
          )
          nodes << splat_list_init << splat_size << splat_string_vars_init <<
            splat_list_idx_init << while_loop
          establish_parents(nodes)
          nodes
        end

        def splat_value
          n = @splat_node
          until DefNode === n || n.nil?
            n = n.parent
          end
          @splat_node.value
          #var_str_without_star = @splat_node.value[1..-1]
          #var_without_star = GetVariableNode.new(nil, var_str_without_star)
          #return var_without_star if n.nil? || !n.splat || (n.splat != @splat_node.value)
          #GetVariableNode.new('a:', '000')
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
          class_node = ast.parent
          class_name = class_node.name
          node.scope_modifier = 's:'
          node.original_name = node.name
          node.name = "#{class_name}_#{node.name}"
          node.sid = nil
          node.keywords -= ['dict']
          node.parameters.unshift(class_node.constructor_obj_name)
          # rewrite `self` in function body to a:#{class_name}Obj
          self_to_obj_argument = SelfToObjArgumentInPrivateFunction.new(node, classes, class_node)
          self_to_obj_argument.rewrite_on_match
          reestablish_parents(node)
        end

        def max_recursion_lvl
          1
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
          node.instance_of?(DefMethodNode)
        end

        def replace(node)
          def_node = node.to_def_node
          class_expressions = ast.expressions
          class_expressions.insert_after(class_expressions.nodes.last, def_node)
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
                    ]
                  )
                ]
              )
            )
          constructor.expressions << extension
          extension.parent = constructor.expressions
        end

        def max_recursion_lvl
          2
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
          # initialize method taking *splat parameter and call super with it
          elsif class_node.superclass?
            def_node = DefNode.new(
              '!', nil, nil, "initialize", ['...'], nil, Nodes.new([SuperNode.new([SplatNode.new(GetVariableNode.new('a:', '000'))], false)])
            )
          else
            def_node = DefNode.new(
              '!', nil, nil, "initialize", [], nil, Nodes.new([])
            )
          end
          class_node.expressions.nodes.unshift(def_node)
          reestablish_parents(class_node)
        end

        def superclass_params
          classes.superclass(ast.full_name).constructor.parameters
        end

        def imported_superclass?
          classes.superclass(ast.full_name).imported?
        end

        def max_recursion_lvl
          1
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
            error_msg "class #{class_node.full_name.inspect} called super in its " \
              " initialize function, but it has no superclass."
            error = InvalidSuper.new(error_msg, constructor)
            raise error
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

        def max_recursion_lvl
          1
        end
      end

      # rewrites calls to 'super' in public/private non-initialize functions
      class SuperToSuperclassFunction < AST_Rewriter
        def match?(node)
          return false unless SuperNode === node
          n = node
          n = n.parent until DefNode === n || n.nil?
          return false if n.nil? || ast.constructor == n
          @function_node = n
        end

        def replace(node)
          func_scope = 's:'
          superclass = classes[ast.superclass_full_name]
          while superclass && !superclass.has_function?(func_scope, superclass_func_name(superclass)) && superclass.superclass?
            superclass = classes[superclass.superclass_full_name]
          end
          superclass_function = superclass.find_function(func_scope, superclass_func_name(superclass))
          if superclass.nil? || !superclass_function
            error_msg = "super was called in class #{ast.full_name} in " \
              "function #{@function_node.original_name}, but there are no " \
              "functions with this name in that class's superclass hierarchy."
            error = Riml::InvalidSuper.new(error_msg, node)
            raise error
          end
          node_args = if node.arguments.empty? && !node.with_parens && superclass_function.splat
            [SplatNode.new(GetVariableNode.new('a:', '000'))]
          else
            if @function_node.private_function?
              node.arguments.unshift GetVariableNode.new(nil, @function_node.parameters.first)
            end
            node.arguments
          end
          # check if SplatNode is in node_args. If it is, check if the splat
          # value is equal to splat param. If it is, and we're inside a
          # private function, we have to add the explicit object (first
          # parameter to the function we're in) to the splat arg
          if @function_node.private_function?
            if (splat_node = node_args.detect { |arg| SplatNode === arg })
              splat_node.value = WrapInParensNode.new(
                BinaryOperatorNode.new(
                  '+',
                  [
                    ListNode.new([
                      GetVariableNode.new('a:', @function_node.parameters.first)
                    ]),
                    GetVariableNode.new('a:', '000')
                  ]
                )
              )
              establish_parents(splat_node.value)
            end
            # call s.ClassA_private_func(args)
            call_node_name = superclass_func_name(superclass)
          else
            # call self.ClassA_public_func(args)
            call_node_name = DictGetDotNode.new(
              GetVariableNode.new(nil, 'self'),
              [superclass_func_name(superclass)]
            )
          end
          call_node = CallNode.new(
            nil,
            call_node_name,
            node_args
          )

          node.replace_with(call_node)
          # private functions are NOT extended in constructor function
          unless @function_node.private_function?
            add_superclass_func_ref_to_constructor(superclass)
          end
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
                  ]
                )
              ]
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
            error_msg = "can't have regular parameter after default parameter in function #{def_node.name.inspect}"
            error = UserArgumentError.new(error_msg, def_node)
            raise error
          end
        end

        if_expression = construct_if_expression(node)

        if last_default_param == node
          def_node.parameters.delete_if(&DefNode::DEFAULT_PARAMS)
          def_node.parameters << SPLAT_LITERAL unless def_node.splat
        end
        def_node.expressions.nodes.insert(insert_idx, if_expression)
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

      def max_recursion_lvl
        3
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

      def max_recursion_lvl
        1
      end
    end

  end unless defined?(Riml::AST_Rewriter)
end
