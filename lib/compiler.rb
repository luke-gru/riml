require File.expand_path('../nodes', __FILE__)

# visits AST nodes and translates them into VimL
module Riml
  class Compiler
    attr_accessor :parser

    # Base abstract visitor
    class Visitor
      attr_writer :propagate_up_tree
      attr_reader :value

      def initialize(options={})
        @propagate_up_tree = options[:propagate_up_tree]
      end

      def visit(node)
        @value = compile(node)
        @value << "\n" if node.force_newline and @value[-1] != "\n"
        propagate_up_tree(node, @value)
      end

      def propagate_up_tree(node, output)
        node.parent_node.compiled_output << output.to_s unless @propagate_up_tree == false || node.parent_node.nil?
      end

      def visitor_for_node(node, params={})
        Compiler.const_get("#{node.class.name}Visitor").new(params)
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
          node.compiled_output << (line =~ /else|elseif\n\Z/ ? line : node.indent + line)
        end
        node.compiled_output << "\n" unless node.compiled_output[-1] == "\n"
        node.force_newline = true
        node.compiled_output << "endif"
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
        node.force_newline = true
        node.compiled_output << "endwhile"
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
        when NilClass
          'nil'
        when Numeric
          node.value
        when String
          StringNode === node ? string_surround(node) : node.value
        when Array
          node.value.each {|n| n.parent_node = node}
          '[' <<
          node.value.map do |n|
            n.accept(visitor_for_node(n))
            n.compiled_output
          end.join(', ') << ']'
        when Hash
          node.value.each {|k_n, v_n| k_n.parent_node, v_n.parent_node = node, node}
          '{' <<
          node.value.map do |k,v|
            k.accept(visitor_for_node(k))
            v.accept(visitor_for_node(v))
            k.compiled_output << ': ' << v.compiled_output
          end.join(', ') << '}'
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
    NilNodeVisitor   = LiteralNodeVisitor

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

      private
      def scope_modifier_for_node(node)
        if node.scope
          return "a:" if node.scope.argument_variable_names.include?(node.name)
          return "" unless node.is_a?(CallNode)
        end
        return "" if (node.is_a?(CallNode) || node.is_a?(DefNode)) && node.autoload?
        "s:"
      end
    end

    class AssignNodeVisitor < ScopedVisitor
      def compile(node)
        node.lhs.accept(visitor_for_node(node.lhs, :propagate_up_tree => false))
        node.compiled_output = "let #{node.lhs.compiled_output} #{node.operator} "
        node.rhs.parent_node = node
        node.rhs.accept(visitor_for_node(node.rhs))
        node.compiled_output = "unlet! #{node.lhs.compiled_output}" if node.rhs.compiled_output == 'nil'
        node.force_newline = true
        node.compiled_output
      end
    end

    # scope_modifier, name
    class GetVariableNodeVisitor < ScopedVisitor
      def compile(node)
        set_modifier(node)

        if node.scope && node.scope.function? && (splat = node.scope.function.splat)
          check_for_splat_match!(node, splat)
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
            part.value
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
        setup_local_scope_for_descendants(node)
        super
      end

      def compile(node)
        set_modifier(node)
        bang = node.bang
        params = process_parameters!(node)
        declaration = "function#{bang} #{node.scope_modifier}"
        declaration <<
        if node.name.respond_to?(:variable)
          node.name.accept(visitor_for_node(node.name))
          node.name.compiled_output
        else
          node.name
        end << "(#{params.join(', ')})"
        declaration << (node.keyword ? " #{node.keyword}\n" : "\n")
        node.expressions.parent_node = node
        node.expressions.accept NodesVisitor.new(:propagate_up_tree => false)

        body = ""
        unless node.expressions.compiled_output.empty?
          node.expressions.compiled_output.each_line do |line|
            body << node.indent + line
          end
        end
        node.compiled_output = declaration << body << "endfunction\n"
      end

      private
      def setup_local_scope_for_descendants(node)
        node.expressions.accept(EstablishScopeVisitor.new(:scope => node.to_scope))
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
          expr.accept(self) if expr.respond_to?(:accept)
        end if node.respond_to?(:each)
      end
    end

    class EstablishScopeVisitor < DrillDownVisitor
      def initialize(options)
        @scope = options[:scope]
      end

      def visit(node)
        establish_scope(node)
      end

      def establish_scope(node)
        if node.scope
          node.scope = node.scope.merge @scope
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
        node.compiled_output << (node.builtin_command? ? " " : "(")
        node.arguments.each_with_index do |arg, i|
          arg.parent_node = node
          arg_visitor = visitor_for_node(arg)
          arg.accept(arg_visitor)
          node.compiled_output << ", " unless last_arg?(node.arguments, i)
        end
        node.compiled_output << ")" unless node.builtin_command?

        unless node.descendant_of_control_structure? ||
               node.descendant_of_call_node? ||
               node.descendant_of_list_node? ||
               node.descendant_of_list_or_dict_get_node? ||
               node.descendant_of_operator_node? ||
               node.descendant_of_wrap_in_parens_node? ||
               node.descendant_of_sublist_node?
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

    class RimlCommandNodeVisitor < CallNodeVisitor
      def compile(node)
        if node.name == 'riml_source'
          node.name = 'source'
          node.each_existing_file! do |file|
            root_node(node).current_compiler.compile_queue << file
          end
        elsif node.name == 'riml_include'
          # riml_include has to be top-level
          unless node.parent == root_node(node)
            error_msg = %Q(riml_include error, has to be called at top-level)
            raise IncludeNotTopLevel, error_msg
          end
          node.each_existing_file! do |file|
            full_path = File.join(Riml.source_path, file)
            riml_src = File.read(full_path)
            node.compiled_output << root_node(node).current_compiler.compile_include(riml_src, file)
          end
          return node.compiled_output
        end
        node.compiled_output << node.name
        compile_arguments(node)
        node.compiled_output.gsub!(/['"]/, '')
        node.compiled_output.sub!('.riml', '.vim')
        node.compiled_output
      end

      def root_node(node)
        @root_node ||= begin
          node = node.parent until node.parent.nil?
          node
        end
      end
    end

    class ForNodeVisitor < Visitor
      def compile(node)
        if node.variables
          node.variables.parent_node = node
          node.variables.each {|v| v.scope_modifier = ""}
          node.variables.accept(
            visitor_for_node(
              node.variables,
              :propagate_up_tree => false
            )
          )
          node.compiled_output = "for #{node.variables.compiled_output} in "
        else
          node.compiled_output = "for #{node.variable} in "
        end
        node.in_expression.parent_node = node
        node.in_expression.force_newline = true
        node.in_expression.accept(visitor_for_node(node.in_expression))
        node.expressions.parent_node = node
        node.expressions.accept(EstablishScopeVisitor.new(:scope => node.to_scope))
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
            node.compiled_output << ( line =~ /\A\s*catch/ ? line : node.indent + line )
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

    def compile_include(source, from_file)
      root_node = parser.parse(source, parser.ast_rewriter, from_file)
      output = compile(root_node)
      (Riml::INCLUDE_COMMENT_FMT % from_file) + output
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
