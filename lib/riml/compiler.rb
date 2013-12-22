require File.expand_path('../nodes', __FILE__)
require File.expand_path('../errors', __FILE__)

# visits AST nodes and translates them into VimL
module Riml
  class Compiler
    attr_accessor :parser
    attr_writer :options

    # compiler options

    def options
      @options ||= {}
    end

    def output_dir
      options[:output_dir]
    end

    def readable
      options.has_key?(:readable) and options[:readable]
    end

    # Base abstract visitor
    class Visitor
      attr_writer :propagate_up_tree

      def initialize(options={})
        @propagate_up_tree = options[:propagate_up_tree]
      end

      def visit(node)
        output = compile(node)
        output << "\n" if node.force_newline and output[-1, 1] != "\n"
        propagate_up_tree(node, output)
      end

      protected

      def propagate_up_tree(node, output)
        node.parent_node.compiled_output << output.to_s unless @propagate_up_tree == false || node.parent_node.nil?
      end

      def visitor_for_node(node, params={})
        Compiler.const_get("#{node.class.name.split('::').last}Visitor").new(params)
      rescue NameError
        error = CompileError.new('unexpected construct', node)
        raise error
      end

      def root_node(node)
        @root_node ||= begin
          node = node.parent until node.parent.nil?
          node
        end
      end

      def current_compiler(node)
        root_node(node).current_compiler
      end
    end

    class IfNodeVisitor < Visitor
      def compile(node)
        condition_visitor = visitor_for_node(node.condition)
        node.condition.parent_node = node
        node.condition.force_newline = true
        node.compiled_output = "if "
        node.compiled_output << "!" if UnlessNode === node

        node.condition.accept(condition_visitor)
        node.body.accept(NodesVisitor.new(:propagate_up_tree => false))

        node.body.compiled_output.each_line do |line|
          outdent = line =~ /\A(\s*)(else\s*|elseif .+)$/
          if outdent && node.non_nested?
            node.compiled_output << node.outdent + line
          else
            node.compiled_output << node.indent + line
          end
        end
        node.compiled_output << "\n" unless node.compiled_output[-1, 1] == "\n"
        node.compiled_output << "endif\n"
      end
    end

    UnlessNodeVisitor = IfNodeVisitor

    class TernaryOperatorNodeVisitor < Visitor
      def compile(node)
        node.operands.each {|n| n.parent_node = node}
        cond_visitor = visitor_for_node(node.condition)
        node.condition.accept(cond_visitor)
        node.compiled_output << ' ? '
        if_expr_visitor = visitor_for_node(node.if_expr)
        node.if_expr.accept(if_expr_visitor)
        node.compiled_output << ' : '
        else_expr_visitor =  visitor_for_node(node.else_expr)
        node.else_expr.accept(else_expr_visitor)
        node.compiled_output
      end
    end

    class WhileNodeVisitor < Visitor
      def compile(node)
        node.condition.force_newline = true
        node.compiled_output = "while "
        node.compiled_output << "!" if UntilNode === node
        node.condition.accept visitor_for_node(node.condition)

        node.body.accept NodesVisitor.new(:propagate_up_tree => false)

        node.body.compiled_output.each_line do |line|
          node.compiled_output << node.indent + line
        end
        node.compiled_output << "endwhile\n"
      end
    end

    UntilNodeVisitor = WhileNodeVisitor

    class ElseNodeVisitor < Visitor
      def compile(node)
        node.compiled_output = "else\n"
        node.expressions.parent = node
        node.expressions.accept(visitor_for_node(node.expressions))
        node.compiled_output
      end
    end

    class ElseifNodeVisitor < Visitor
      def compile(node)
        node.compiled_output = "elseif "
        node.condition.parent_node = node
        node.condition.force_newline = true
        node.condition.accept(visitor_for_node(node.condition))
        node.expressions.parent_node = node
        node.expressions.accept(visitor_for_node(node.expressions))
        node.force_newline = true
        node.compiled_output
      end
    end

    class NodesVisitor < Visitor
      def compile(nodes)
        nodes.each_with_index do |node, i|
          visitor = visitor_for_node(node)
          node.parent_node = nodes
          next_node = nodes.nodes[i+1]
          if ElseNode === next_node
            node.force_newline = true
          end
          node.accept(visitor)
        end
        nodes.compiled_output
      end
    end

    SublistNodeVisitor = NodesVisitor

    class LiteralNodeVisitor < Visitor
      def compile(node)
        value = case node.value
        when TrueClass
          1
        when FalseClass
          0
        when Numeric
          node.value
        when String
          StringNode === node ? string_surround(node) : node.value
        when Array
          if ListNode === node
            node.value.each {|n| n.parent_node = node}
            '[' <<
            node.value.map do |n|
              n.accept(visitor_for_node(n))
              n.compiled_output
            end.join(', ') << ']'
          elsif DictionaryNode === node
            '{' <<
            node.value.map do |(k, v)|
              k.accept(visitor_for_node(k))
              v.accept(visitor_for_node(v))
              k.compiled_output << ': ' << v.compiled_output
            end.join(', ') << '}'
          end
        end.to_s

        node.compiled_output = value
      end

      private
      def string_surround(string_node)
        case string_node.type.to_sym
        when :d
          '"' << string_node.value << '"'
        when :s
          "'" << string_node.value << "'"
        end
      end
    end

    TrueNodeVisitor  = LiteralNodeVisitor
    FalseNodeVisitor = LiteralNodeVisitor

    NumberNodeVisitor = LiteralNodeVisitor
    StringNodeVisitor = LiteralNodeVisitor
    RegexpNodeVisitor = LiteralNodeVisitor
    ExLiteralNodeVisitor = LiteralNodeVisitor

    ListNodeVisitor = LiteralNodeVisitor
    DictionaryNodeVisitor = LiteralNodeVisitor

    ScopeModifierLiteralNodeVisitor = LiteralNodeVisitor
    FinishNodeVisitor = LiteralNodeVisitor
    ContinueNodeVisitor = LiteralNodeVisitor
    BreakNodeVisitor = LiteralNodeVisitor

    class StringLiteralConcatNodeVisitor < Visitor
      def compile(nodes)
        nodes.each_with_index do |node, i|
          visitor = visitor_for_node(node)
          node.parent_node = nodes
          next_node = nodes.nodes[i+1]
          node.accept(visitor)
          nodes.compiled_output << ' ' if next_node
        end
        nodes.compiled_output
      end
    end

    class ListUnpackNodeVisitor < ListNodeVisitor
      def compile(node)
        node.compiled_output = super.reverse.sub(',', ';').reverse
      end
    end

    class ReturnNodeVisitor < Visitor
      def compile(node)
        node.compiled_output = "return"
        node.force_newline = true
        return node.compiled_output if node.expression.nil?
        node.expression.parent_node = node
        node.compiled_output << " "
        node.expression.accept(visitor_for_node(node.expression))
        node.compiled_output
      end
    end

    class WrapInParensNodeVisitor < Visitor
      def compile(node)
        node.compiled_output << "("
        node.expression.parent_node = node
        node.expression.accept(visitor_for_node(node.expression))
        node.compiled_output << ")"
      end
    end

    # common visiting methods for nodes that are scope modified with variable
    # name prefixes
    class ScopedVisitor < Visitor
      private
      def set_modifier(node)
        # Ex: n:myVariable = "override riml default scoping" compiles into:
        #       myVariable = "override riml default scoping"
        if node.scope_modifier == "n:"
          node.scope_modifier = ""
        end
        return node.scope_modifier if node.scope_modifier
        node.scope_modifier = scope_modifier_for_node(node)
      end

      def scope_modifier_for_node(node)
        if node.respond_to?(:name) && node.name == 'self'
          return node.scope_modifier = ''
        end
        if node.scope && node.scope.function?
          if DefNode === node && !node.defined_on_dictionary?
            return "s:"
          elsif GetVariableNode === node &&
                node.scope.function.shadowed_argument?(node.full_name)
            return ""
          elsif node.respond_to?(:name) && node.scope.argument_variable_names.include?(node.name) &&
                !(AssignNode === node.parent && node.parent.lhs == node)
            return "a:"
          elsif !node.is_a?(CallNode)
            return ""
          end
        end
        return "" if node.respond_to?(:autoload?) && node.autoload?
        "s:"
      end
    end

    class AssignNodeVisitor < ScopedVisitor
      def compile(node)
        lhs = visit_lhs(node)
        rhs = visit_rhs(node)
        if GetVariableNode === node.lhs && node.scope && (func = node.scope.function)
          if func.argument_variable_names.include?(node.lhs.full_name)
            if !func.shadowed_argument_variable_names.include?(node.lhs.full_name)
              func.shadowed_argument_variable_names << node.lhs.full_name
            end
          end
        end
        node.compiled_output = "#{lhs}#{rhs}"
        node.force_newline = true
        node.compiled_output
      end

      def visit_lhs(node)
        node.lhs.accept(visitor_for_node(node.lhs, :propagate_up_tree => false))
        "let #{node.lhs.compiled_output} #{node.operator} "
      end

      def visit_rhs(node)
        node.rhs.accept(visitor_for_node(node.rhs, :propagate_up_tree => false))
        node.rhs.compiled_output
      end
    end

    class MultiAssignNodeVisitor < Visitor
      def compile(node)
        node.assigns.each do |assign|
          assign.force_newline = true
          assign.accept(visitor_for_node(assign))
        end
        node.compiled_output
      end
    end

    # scope_modifier, name
    class GetVariableNodeVisitor < ScopedVisitor
      def compile(node)
        set_modifier(node)

        if node.scope && node.scope.function?
          if splat = node.scope.function.splat
            check_for_splat_match!(node, splat)
          end
        end

        if node.question_existence?
          node.compiled_output = %Q{exists("#{node.full_name}")}
        else
          node.compiled_output = "#{node.full_name}"
        end
      end

      private
      def check_for_splat_match!(node, splat)
        # if `function doIt(*options)`, then:
        # *options OR options in function body becomes `a:000`
        if [ splat, splat[1..-1] ].include?(node.name)
          node.scope_modifier = 'a:'
          node.name = '000'
        end
      end
    end

    class GetSpecialVariableNodeVisitor < Visitor
      def compile(node)
        node.compiled_output = node.full_name
      end
    end

    class GetCurlyBraceNameNodeVisitor < ScopedVisitor
      def compile(node)
        set_modifier(node)
        node.compiled_output = node.scope_modifier
        node.compiled_output << compile_parts(node.variable.parts)
      end

      def compile_parts(parts)
        parts.map do |part|
          if CurlyBraceVariable === part
            compile_parts(part)
          elsif part.nested?
            compile_nested_parts(part.value, part)
            part.compiled_output
          elsif part.interpolated?
            part.value.accept(visitor_for_node(part.value))
            "{#{part.value.compiled_output}}"
          else
            if String === part.value
              part.value
            else
              part.value.accept(visitor_for_node(part.value))
              "{#{part.value.compiled_output}}".gsub(/\n/, '')
            end
          end
        end.join
      end

      def compile_nested_parts(parts, root_part)
        nested = 0
        parts.each do |part|
          if !part.respond_to?(:value)
            part.accept(visitor_for_node(part, :propagate_up_tree => false))
            root_part.compiled_output << "{#{part.compiled_output}"
            nested += 1
            next
          end
          if part.value.is_a?(Array)
            compile_nested_parts(part.value, root_part)
            next
          end
          part.value.accept(visitor_for_node(part.value, :propagate_up_tree => false))
          root_part.compiled_output << "{#{part.value.compiled_output}}#{'}' * nested}"
        end
      end
    end

    class UnletVariableNodeVisitor < Visitor
      def compile(node)
        node.variables.each {|v| v.parent_node = node}
        node.compiled_output = "unlet#{node.bang}"
        node.variables.each do |var|
          node.compiled_output << " "
          var.accept(visitor_for_node(var))
        end
        node.compiled_output
      end
    end

    # operator, operands
    class BinaryOperatorNodeVisitor < Visitor
      def compile(node)
        op1, op2 = node.operand1, node.operand2
        [op1, op2].each {|n| n.parent = node}
        op1.accept(visitor_for_node(op1))
        if node.ignorecase_capable_operator?(node.operator)
          operator_suffix = "# "
        else
          operator_suffix = " "
        end
        node.compiled_output << " #{node.operator}#{operator_suffix}"
        op2.accept(visitor_for_node(op2))
        node.compiled_output
      end
    end

    class UnaryOperatorNodeVisitor < Visitor
      def compile(node)
        node.compiled_output << node.operator
        node.operand.parent_node = node
        node.operand.accept(visitor_for_node(node.operand))
        node.compiled_output
      end
    end

    class DefNodeVisitor < ScopedVisitor
      def visit(node)
        options = {}
        if node.nested_function?
          options[:nested_function] = true
        end
        setup_local_scope_for_descendants(node, options)
        super
      end

      def compile(node)
        set_modifier(node)
        bang = node.bang
        params = process_parameters!(node)
        declaration = "function#{bang} #{node.sid}#{node.scope_modifier}"
        declaration <<
        if node.name.respond_to?(:variable)
          node.name.accept(visitor_for_node(node.name))
          node.name.compiled_output
        else
          node.name
        end << "(#{params.join(', ')})"
        declaration << (node.keywords.empty? ? "\n" : " #{node.keywords.join(' ')}\n")
        node.expressions.parent_node = node
        node.expressions.accept NodesVisitor.new(:propagate_up_tree => false)

        body = ""
        unless node.expressions.compiled_output.empty?
          node.expressions.compiled_output.each_line do |line|
            body << node.indent + line
          end
        end
        node.compiled_output = declaration << body << "endfunction\n"
        if current_compiler(node).readable
          node.compiled_output << "\n"
        else
          node.compiled_output
        end
      end

      private
      def setup_local_scope_for_descendants(node, options)
        options.merge!(:scope => node.to_scope)
        node.expressions.accept(EstablishScopeVisitor.new(options))
      end

      def process_parameters!(node)
        splat = node.splat
        return node.parameters unless splat
        node.parameters.map {|p| p == splat ? '...' : p}
      end
    end

    # helper to drill down to all descendants of a certain node and do
    # something to all or a set of them
    class DrillDownVisitor < Visitor
      def walk_node!(node)
        node.each do |expr|
          expr.accept(self) if Visitable === expr
        end if node.respond_to?(:each)
      end
    end

    class EstablishScopeVisitor < DrillDownVisitor
      def initialize(options)
        @scope = options[:scope]
        @nested_function = options[:nested_function]
      end

      def visit(node)
        establish_scope(node)
      end

      def establish_scope(node)
        if node.scope && !@nested_function
          node.scope = node.scope.merge @scope
        elsif node.scope
          node.scope = @scope.merge_parent_function(node.scope)
        else
          node.scope = @scope
        end
        walk_node!(node)
      end
    end

    class CallNodeVisitor < ScopedVisitor
      def compile(node)
        set_modifier(node) if node.name && !node.builtin_function?
        node.compiled_output =
          if node.name.respond_to?(:variable)
            node.name.accept(visitor_for_node(node.name))
            node.scope_modifier + node.name.compiled_output
          elsif DictGetDotNode === node.name
            node.name.accept(visitor_for_node(node.name))
            node.name.compiled_output
          else
            node.full_name
          end
        compile_arguments(node)
        node.compiled_output
      end

      def compile_arguments(node)
        builtin_cmd = node.builtin_command?
        node.compiled_output << if builtin_cmd
          if node.arguments.any? then ' ' else '' end
        else
          '('
        end
        node.arguments.each_with_index do |arg, i|
          arg.parent_node = node
          arg_visitor = visitor_for_node(arg)
          arg.accept(arg_visitor)
          node.compiled_output << ", " unless last_arg?(node.arguments, i)
        end
        node.compiled_output << ")" unless builtin_cmd
        node_p = node.parent
        if node_p.force_newline_if_child_call_node?
          node.force_newline = true
        end
      end

      private
      def last_arg?(args, i)
        args[i+1].nil?
      end
    end

    class ExplicitCallNodeVisitor < CallNodeVisitor
      def compile(node)
        if node.scope_modifier || node.name
          node.compiled_output = "call " << super
        else
          node.compiled_output = "call"
          compile_arguments(node)
        end
        node.compiled_output
      end
    end

    class RimlFileCommandNodeVisitor < CallNodeVisitor
      def compile(node)
        if node.name == 'riml_source'
          node.name = 'source'
          node.each_existing_file! do |basename, full_path|
            current_compiler(node).compile_queue << [basename, full_path]
          end
        elsif node.name == 'riml_include'
          # riml_include has to be top-level
          unless node.parent == root_node(node)
            error_msg = %Q(riml_include error, has to be called at top-level)
            error = IncludeNotTopLevel.new(error_msg, node)
            raise error
          end
          node.each_existing_file! do |basename, full_path|
            output = current_compiler(node).compile_include(basename, full_path)
            node.compiled_output << output if output
          end
          return node.compiled_output
        end
        node.compiled_output << node.name
        compile_arguments(node)
        node.compiled_output.gsub!(/['"]/, '')
        node.compiled_output.sub!('.riml', '.vim')
        node.compiled_output
      end
    end

    class ForNodeVisitor < ScopedVisitor
      def compile(node)
        scope_visitor = EstablishScopeVisitor.new(:scope => node.to_scope)
        if node.variables
          node.variables.parent_node = node
          node.variables.accept(scope_visitor)
          node.variables.accept(
            visitor_for_node(
              node.variables,
              :propagate_up_tree => false
            )
          )
          node.compiled_output = "for #{node.variables.compiled_output} in "
        else
          node.variable.parent_node = node
          node.variable.accept(scope_visitor)
          set_modifier(node.variable)
          node.compiled_output = "for #{node.variable.full_name} in "
        end
        node.in_expression.parent_node = node
        node.in_expression.force_newline = true
        node.in_expression.accept(visitor_for_node(node.in_expression))
        node.expressions.parent_node = node
        node.expressions.accept(scope_visitor)
        node.expressions.accept(NodesVisitor.new :propagate_up_tree => false)
        body = node.expressions.compiled_output
        body.each_line do |line|
          node.compiled_output << node.indent + line
        end
        node.compiled_output << "endfor\n"
      end
    end

    class TryNodeVisitor < Visitor
      # try_block, catch_nodes, finally_block
      def compile(node)
        try, catches, finally = node.try_block, node.catch_nodes, node.finally_block
        node.compiled_output = "try\n"
        try.accept(visitor_for_node(try, :propagate_up_tree => false))
        try.compiled_output.each_line do |line|
          node.compiled_output << node.indent + line
        end

        catches.each do |c|
          c.accept(visitor_for_node(c, :propagate_up_tree => false))
          c.compiled_output.each_line do |line|
            outdent = line =~ /\A\s*catch/
            if outdent && c.non_nested?
              node.compiled_output << node.outdent + line
            else
              node.compiled_output << node.indent + line
            end
          end
        end if catches

        if finally
          node.compiled_output << "finally\n"
          finally.accept(visitor_for_node(finally, :propagate_up_tree => false))
          finally.compiled_output.each_line do |line|
            node.compiled_output << node.indent + line
          end
        end
        node.compiled_output << "endtry\n"
      end
    end

    class CatchNodeVisitor < Visitor
      # regexp, block
      def compile(node)
        regexp, exprs = node.regexp, node.expressions
        node.compiled_output = "catch"
        exprs.parent_node = node
        if regexp
          regexp.parent_node = node
          node.compiled_output << " "
          regexp.accept(visitor_for_node(regexp))
        end
        node.compiled_output << "\n"
        exprs.accept(visitor_for_node(exprs))
        node.compiled_output
      end
    end

    class DictGetBracketNodeVisitor < Visitor
      def compile(node)
        node.dict.parent_node = node
        node.keys.each do |k|
          k.parent_node = node
        end
        node.dict.accept(visitor_for_node(node.dict))
        node.keys.each do |key|
          node.compiled_output << '['
          key.accept(visitor_for_node(key))
          node.compiled_output << ']'
        end
        node.compiled_output
      end
    end

    class ListOrDictGetNodeVisitor < DictGetBracketNodeVisitor; end

    class DictGetDotNodeVisitor < Visitor
      def compile(node)
        node.dict.parent_node = node
        node.dict.accept(visitor_for_node(node.dict))
        node.keys.each do |key|
          node.compiled_output << ".#{key}"
        end
        node.compiled_output
      end
    end

    class GetVariableByScopeAndDictNameNodeVisitor < Visitor
      def compile(node)
        node.scope_modifier.parent = node
        node.scope_modifier.accept(visitor_for_node(node.scope_modifier))
        node.keys.each do |key|
          key.parent = node
          node.compiled_output << '['
          key.accept(visitor_for_node(key))
          node.compiled_output << ']'
        end
        node.compiled_output
      end
    end

    class ClassDefinitionNodeVisitor < Visitor
      def compile(node)
        node.expressions.parent_node = node
        node.expressions.accept(NodesVisitor.new)
        node.compiled_output
      end
    end

    class ObjectInstantiationNodeVisitor < Visitor
      def compile(node)
        node.call_node.parent_node = node
        node.call_node.accept(visitor_for_node(node.call_node))
        node.compiled_output
      end
    end

    # root node has access to compiler instance in order to append to
    # the compiler's `compile_queue`. This happens when another file is
    # sourced using `riml_source`.
    module CompilerAccessible
      attr_accessor :current_compiler
    end

    def compile_queue
      @compile_queue ||= []
    end

    def sourced_files_compiled
      @sourced_files_compiled ||= []
    end

    def included_files_compiled
      @included_files_compiled ||= []
    end

    def compile_include(file_basepath, file_fullpath)
      return if included_files_compiled.include?(file_basepath)
      Riml.include_cache.fetch(file_basepath) do
        source = File.read(file_fullpath)
        root_node = parser.parse(source, parser.ast_rewriter, file_basepath, true)
        included_files_compiled << file_basepath
        output = compile(root_node)
        (Riml::INCLUDE_COMMENT_FMT % file_basepath) + output
      end
    end

    # compiles nodes into output code
    def compile(root_node)
      root_node.extend CompilerAccessible
      root_node.current_compiler = self
      root_node.accept(NodesVisitor.new)
      root_node.compiled_output
    end

  end
end
