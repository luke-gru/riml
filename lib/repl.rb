begin
  require 'readline'
rescue LoadError => e
  $stderr.puts e, "Readline is required to run repl."
  exit 1
end
require_relative 'riml'

module Riml
  class Repl
    attr_reader :line

    def initialize(vi_readline = false)
      @indent_amount = 0
      @line = nil
      Readline.vi_editing_mode if vi_readline
      trap(:INT) { reset! }
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
      lexer = Lexer.new("#{line}\n")
      lexer.ignore_indentation_check = true
      lexer.tokenize
      @indent_amount += lexer.current_indent
    rescue => e
      print_error(e)
      reset!
    end

    def current_indent
      return '' if @indent_amount <= 0
      ' ' * @indent_amount
    end

    def compile_unit!
      puts Riml.compile(current_compilation_unit.join("\n"))
    rescue => e
      raise unless e.kind_of?(RimlError)
      print_error(e)
    ensure
      @indent_amount = 0
      current_compilation_unit.clear
    end

    def current_compilation_unit
      @current_compilation_unit ||= []
    end

    def reset!
      @indent_amount = 0
      current_compilation_unit.clear
      print("\n")
    end

    def print_error(e)
      puts "#{e.class}: #{e}"
    end

    def exit_repl
      exit
    end
  end
end
