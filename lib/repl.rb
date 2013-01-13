require 'readline'
require_relative 'riml'

module Riml
  class Repl
    attr_reader :line

    def initialize(vi_readline = false)
      @indent_amount = 0
      @line = nil
      Readline.vi_editing_mode if vi_readline
    end

    def run
      while @line = Readline.readline(current_indent, true)
        line.strip!
        next if line.empty?
        exit_repl if line == 'quit' || line == 'q'
        if line == 'c'
          next if current_compilation_unit.empty?
          compile_unit!
        else
          current_compilation_unit << line
          check_indents
        end
      end
    end

    private

    def check_indents
      @lexer = Lexer.new("#{line}\n")
      @lexer.ignore_indentation_check = true
      @lexer.tokenize
      indent = @lexer.current_indent
      @indent_amount += indent
    end

    def current_indent
      " " * @indent_amount.abs
    end

    def compile_unit!
      @indent_amount = 0
      puts Riml.compile(current_compilation_unit.join("\n"))
      current_compilation_unit.clear
    end

    def current_compilation_unit
      @current_compilation_unit ||= []
    end

    def exit_repl
      exit
    end
  end
end
