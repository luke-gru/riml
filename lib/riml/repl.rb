begin
  require 'readline'
rescue LoadError => e
  $stderr.puts e, "Readline is required to run repl."
  exit 1
end

require 'ostruct'
require File.expand_path('../../riml', __FILE__)

module Riml
  class Repl
    attr_reader :line
    attr_reader :parser, :compiler, :compiler_options
    private :parser, :compiler

    COMPILE_ON = %w(compile c)
    EXIT_ON = %w(quit q)
    EXECUTE_RIML_ON = %w(execute\ <<riml)
    END_EXECUTE_RIML_ON = %w(riml)

    HELP_MSG = <<msg
compile riml line(s):             #{COMPILE_ON.join(', ')}
execute riml code:                execute \<\<riml
                                    code goes here!
                                  riml
exit repl:                        #{EXIT_ON.join(', ')}
msg

    def initialize(vi_readline = false, compile_options = {})
      @indent_amount = 0
      @line = nil
      @compiler_options = DEFAULT_COMPILE_OPTIONS.merge(compile_options)
      @in_execute_heredoc = false
      Riml.config = OpenStruct.new if Riml.config.nil?
      Riml.config.repl = true
      prepare_new_context
      Readline.vi_editing_mode if vi_readline
    end

    def run
      trap(:INT) { reset!; puts }
      puts HELP_MSG, "\n"
      while @line = Readline.readline(current_indent, true)
        line.strip!
        next if line.empty?
        line_dc = line.downcase
        if @in_execute_heredoc && END_EXECUTE_RIML_ON.include?(line_dc)
          riml = compile_unit
          output = eval_riml(riml)
          puts riml
          puts "\n", "#=>", output
          reset!
        elsif !@in_execute_heredoc && EXECUTE_RIML_ON.include?(line_dc)
          reset!
          @in_execute_heredoc = true
        elsif COMPILE_ON.include?(line_dc)
          next if current_compilation_unit.empty?
          compile_unit!
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
      @compiler.options = compiler_options
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
      viml = compile_unit
      puts viml, "\n"
    rescue => e
      print_error(e)
      reload!
    ensure
      reset!
    end

    def compile_unit
      Riml.do_compile(current_compilation_unit.join("\n"), parser, compiler).chomp
    end

    # TODO: Start only 1 vim process and use pipes to save time when using
    # `execute <<riml` multiple times in the same repl session.
    def eval_riml(riml)
      require 'tempfile' unless defined?(Tempfile)
      infile, outfile = Tempfile.new('in'), Tempfile.new('out')
      riml = Riml::GET_SID_FUNCTION_SRC + "\n#{riml}"
      infile.write("redir! > #{outfile.path}\n#{riml}\nredir END\nq!")
      infile.close
      system("vim -c \"source #{infile.path}\"")
      outfile.read.sub(/\A\n/, '')
    ensure
      infile.close
      outfile.close
    end

    def current_compilation_unit
      @current_compilation_unit ||= []
    end

    def reset!
      @indent_amount = 0
      @in_execute_heredoc = false
      current_compilation_unit.clear
    end

    def print_error(e)
      puts e.verbose_message
    end

    def exit_repl
      exit
    end
  end
end
