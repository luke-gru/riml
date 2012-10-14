require File.expand_path('../nodes', __FILE__)

# visits AST nodes and translates them into VimL
module Riml
  class Compiler

    # Base abstract visitor
    class Visitor
      attr_accessor :propagate_up_tree
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
        node.body.parent_node = node
        node.compiled_output = "if ("
        node.compiled_output << "!" if UnlessNode === node

        node.condition.accept(condition_visitor)
        node.compiled_output << ")\n"
        node.body.accept(NodesVisitor.new(:propagate_up_tree => false))

        node.body.compiled_output.each_line do |line|
          node.compiled_output << (line =~ /else\n\Z/ ? line : node.indent + line)
        end
        node.compiled_output << "\n" unless node.compiled_output[-1] == "\n"
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
        cond_visitor = visitor_for_node(node.condition)
        node.condition.parent_node = node
        node.body.parent_node = node
        node.compiled_output = "while ("
        node.compiled_output << "!" if UntilNode === node

        node.condition.accept(cond_visitor)
        node.compiled_output << ")\n"

        output = node.compiled_output.dup
        node.compiled_output.clear

        node.body.accept(NodesVisitor.new)
        node.compiled_output.each_line do |line|
          output << node.indent + line
        end
        node.compiled_output = output << "\n"
        node.compiled_output << "endwhile\n"
      end
    end

    UntilNodeVisitor = WhileNodeVisitor

    class ElseNodeVisitor < Visitor
      def compile(node)
        node.compiled_output = "else\n"
        expressions_visitor = NodesVisitor.new
        node.expressions.parent_node = node
        node.expressions.accept(expressions_visitor)
        node.compiled_output
      end
    end

    class NodesVisitor < Visitor
      def compile(nodes)
        nodes.each_with_index do |node, i|
          visitor = visitor_for_node(node)
          next_node = nodes.nodes[i+1]
          node.parent_node = nodes
          if ElseNode === next_node
            node.force_newline = true
          end
          node.accept(visitor)
        end
        nodes.compiled_output
      end
    end

    class LiteralNodeVisitor < Visitor
      def compile(node)
        value = case node.value
        when TrueClass
          1
        when FalseClass
          0
        when NilClass
          'nil'
        when String
          StringNode === node ? escape(node) : node.value.dup
        when Array
          node.value.each {|n| n.parent_node = node}
          '[' << node.value.map {|n| compile(n)}.join(', ') << ']'
        when Hash
          node.value.each {|k_n, v_n| k_n.parent_node, v_n.parent_node = [node, node]}
          '{' << node.value.map {|k,v| compile(k) << ': ' << compile(v)}.join(', ') << '}'
        when Numeric
          node.value
        end.to_s

        node.compiled_output = value
      rescue NoMethodError
        if GetVariableNode === node
          node.accept(GetVariableNodeVisitor.new)
          node.compiled_output
        else raise end
      end

      private
      def escape(string_node)
        case string_node.type
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

    ListNodeVisitor = LiteralNodeVisitor
    DictionaryNodeVisitor = LiteralNodeVisitor

    FinishNodeVisitor = LiteralNodeVisitor
    ContinueNodeVisitor = LiteralNodeVisitor
    BreakNodeVisitor = LiteralNodeVisitor

    class HeredocNodeVisitor < Visitor
      def compile(node)
        node.string_node.parent_node = node
        node.string_node.accept(StringNodeVisitor.new)
        node.compiled_output
      end
    end

    class ReturnNodeVisitor < Visitor
      def compile(node)
        node.expression.parent_node = node
        node.compiled_output = "return "
        node.expression.accept(visitor_for_node(node.expression))
        node.force_newline = true
        node.compiled_output
      end
    end

    # common visiting methods for nodes that are scope modified with variable
    # name prefixes
    class ScopedVisitor < Visitor
      private
      def set_modifier(node)
        # Ex: n:myVariable = "override riml default scoping" compiles into:
        #       myVariable = "override riml default scoping"
        node.scope_modifier = "" if node.scope_modifier == "n:"
        return node.scope_modifier if node.scope_modifier
        node.scope_modifier = scope_modifier_for_variable_name(node)
      end

      private
      def scope_modifier_for_variable_name(node)
        if node.scope
          return "a:" if node.scope.arg_variables.include?(node.name)
          return ""
        end
        "s:"
      end
    end

    class SetVariableNodeVisitor < ScopedVisitor
      def compile(node)
        set_modifier(node)

        value_visitor = visitor_for_node(node.value)
        node.compiled_output = "let #{node.full_name} = "
        node.value.parent_node = node
        node.value.accept(value_visitor)
        node.compiled_output = "unlet! #{node.full_name}" if node.value.compiled_output == 'nil'
        node.force_newline = true
        node.compiled_output
      end
    end

    # list, expression
    class SetVariableNodeListVisitor < Visitor
      def compile(node)
        node.compiled_output = "let "
        node.list.parent_node = node
        node.list.accept(ListNodeVisitor.new)
        node.compiled_output << " = "
        node.expression.parent_node = node
        node.expression.accept(visitor_for_node(node.expression))
        node.compiled_output
      end
    end

    class SetSpecialVariableNodeVisitor < Visitor
      def compile(node)
        node.compiled_output = "let #{node.full_name} = "
        value_visitor = visitor_for_node(node.value)
        node.value.parent_node = node
        node.value.accept(value_visitor)
        node.force_newline = true
        node.compiled_output
      end
    end

    # scope_modifier, name
    class GetVariableNodeVisitor < ScopedVisitor
      def compile(node)
        # the variable is a ForNode variable
        scope = node.parent_node && node.parent_node.scope
        if scope && scope.respond_to?(:for_variable) &&
           scope.for_variable == node.name && node.scope_modifier.nil?
          return node.name
        end

        set_modifier(node)
        if node.scope && node.scope.respond_to?(:splat) && (splat = node.scope.splat)
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
        if node.name == splat[1..-1]
          node.scope_modifier = "a:"
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
        node.variable.parts.each do |part|
          node.compiled_output <<
          if part.interpolated?
            part.value.accept(visitor_for_node(part.value))
            "{#{part.value.compiled_output}}"
          else
            "#{part.value}"
          end
        end
        node.compiled_output
      end
    end

    class UnletVariableNodeVisitor < Visitor
      def compile(node)
        node.variables.each {|v| v.parent_node = node}
        node.compiled_output = "unlet!"
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
        op1_visitor, op2_visitor = visitor_for_node(op1), visitor_for_node(op2)
        node.operands.each {|n| n.parent_node = node}
        op1.accept(op1_visitor)
        op2_visitor.propagate_up_tree = false
        op2.accept(op2_visitor)
        if node.ignorecase_capable_operator?(node.operator)
          operator_suffix = "# "
        else
          operator_suffix = " "
        end
        node.compiled_output << " #{node.operator}#{operator_suffix}"
        op2_visitor.propagate_up_tree = true
        op2.accept(op2_visitor)
        node.compiled_output
      end
    end

    class DefNodeVisitor < Visitor
      def visit(node)
        setup_local_scope_for_descendants(node)
        super
      end

      def compile(node)
        modifier = node.scope ? nil : node.scope_modifier || 's:'
        params = process_parameters!(node)
        declaration = "function! #{modifier}"
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
        node.expressions.accept(EstablishScopeVisitor.new(:scope => node))
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
        end
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
        node.scope = @scope
        walk_node!(node) if node.respond_to?(:each)
      end
    end

    class CallNodeVisitor < ScopedVisitor
      def compile(node)
        set_modifier(node) unless node.builtin_function?
        node.compiled_output =
        if node.name.respond_to?(:variable)
          node.name.accept(visitor_for_node(node.name))
          node.scope_modifier + node.name.compiled_output
        elsif DictGetDotNode === node.name
          node.name.accept(visitor_for_node(node.name))
          node.name.compiled_output
        else
          "#{node.full_name}"
        end
        node.compiled_output << (node.no_parens_necessary? ? " " : "(")
        node.arguments.each_with_index do |arg, i|
          arg.parent_node = node
          arg_visitor = visitor_for_node(arg)
          arg.accept(arg_visitor)
          node.compiled_output << ", " unless last_arg?(node.arguments, i)
        end
        node.compiled_output << ")" unless node.no_parens_necessary?

        unless node.descendant_of_control_structure? ||
               node.descendant_of_call_node? ||
               node.descendant_of_list_or_dict_get_node?
          node.compiled_output << "\n"
        end
        node.compiled_output
      end

      private
      def last_arg?(args, i)
        args[i+1].nil?
      end
    end

    class ExplicitCallNodeVisitor < CallNodeVisitor
      def compile(node)
        pre = "call "
        post = super
        node.compiled_output = pre << post
      end
    end

    class ForNodeVisitor < Visitor
      def compile(node)
        node.compiled_output = "for #{node.variable} in "
        node.list_expression.parent_node = node
        yield
        node.expressions.parent_node = node
        node.expressions.accept(EstablishScopeVisitor.new(:scope => node))
        node.expressions.accept(NodesVisitor.new :propagate_up_tree => false)
        body = node.expressions.compiled_output
        body.each_line do |line|
          node.compiled_output << node.indent + line
        end
        node.compiled_output << "endfor"
      end
    end

    class ForNodeCallVisitor < ForNodeVisitor
      def compile(node)
        super do
          node.list_expression.accept(CallNodeVisitor.new)
        end
      end
    end

    class ForNodeListVisitor < ForNodeVisitor
      def compile(node)
        super do
          result = node.list_expression.accept(ListNodeVisitor.new)
          result << "\n" unless result[-1] == "\n"
        end
      end
    end

    class TryNodeVisitor < Visitor
      # try_block, catch_nodes, ensure_block
      def compile(node)
        try, catches, _ensure = node.try_block, node.catch_nodes, node.ensure_block
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

        if _ensure
          node.compiled_output << "finally\n"
          _ensure.accept(visitor_for_node(_ensure, :propagate_up_tree => false))
          _ensure.compiled_output.each_line do |line|
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
        node.keys.each {|k| k.parent_node = node}
        node.dict.accept(visitor_for_node(node.dict))
        node.keys.each do |key|
          node.compiled_output << '['
          key.accept(visitor_for_node(key))
          node.compiled_output << "]"
        end
        node.compiled_output
      end
    end

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

    class DictSetNodeVisitor < Visitor
      def compile(node)
        [node.dict, node.val].each {|n| n.parent_node = node}
        node.compiled_output = "let "
        node.dict.accept(visitor_for_node(node.dict))
        node.keys.each {|k| node.compiled_output << ".#{k}"}
        node.compiled_output << " = "
        node.val.accept(visitor_for_node(node.val))
        node.compiled_output << "\n"
      end
    end

    class ListOrDictGetNodeVisitor < DictGetBracketNodeVisitor; end

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

    # compiles nodes into output code
    def compile(root_node)
      root_visitor = NodesVisitor.new
      root_node.accept(root_visitor)
      root_node.compiled_output
    end

  end
end
