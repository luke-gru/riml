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
    attr_reader :parser, :compiler
    private :parser, :compiler

    COMPILE_ON = %w(compile c)
    RELOAD_ON = %w(reload r)
    EXIT_ON = %w(quit q)

    HELP_MSG = <<msg
compile riml line(s):             #{COMPILE_ON.join(', ')}
clear previous class definitions: #{RELOAD_ON.join(', ')}
exit repl:                        #{EXIT_ON.join(', ')}
msg

    def initialize(vi_readline = false)
      @indent_amount = 0
      @line = nil
      prepare_new_context
      Readline.vi_editing_mode if vi_readline
      trap(:INT) { reset!; puts }
    end

    def run
      puts HELP_MSG, "\n"
      while @line = Readline.readline(current_indent, true)
        line.strip!
        next if line.empty?
        line_dc = line.downcase
        if COMPILE_ON.include?(line_dc)
          next if current_compilation_unit.empty?
          compile_unit!
        elsif RELOAD_ON.include?(line_dc)
          reload!
          puts "reloaded"
        elsif EXIT_ON.include?(line_dc)
          exit_repl
        else
          current_compilation_unit << line
          check_indents
        end
      end
    end

    private

    def prepare_new_context
      @compiler = Compiler.new
      @parser = Parser.new
    end
    alias reload! prepare_new_context

    def check_indents
      lexer = Lexer.new(line)
      lexer.ignore_indentation_check = true
      lexer.tokenize
      @indent_amount += lexer.current_indent
    rescue => e
      print_error(e)
      reset!
      reload!
    end

    def current_indent
      return '' if @indent_amount <= 0
      ' ' * @indent_amount
    end

    def compile_unit!
      viml = Riml.compile(current_compilation_unit.join("\n"), parser, compiler).chomp
      puts viml, "\n"
    rescue => e
      print_error(e)
      reload!
    ensure
      reset!
    end

    def current_compilation_unit
      @current_compilation_unit ||= []
    end

    def reset!
      @indent_amount = 0
      current_compilation_unit.clear
    end

    def print_error(e)
      puts "#{e.class}: #{e}"
    end

    def exit_repl
      exit
    end
  end
end
