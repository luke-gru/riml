require File.expand_path('../environment', __FILE__)
require 'nodes'
require 'lexer'
require 'parser'
require 'compiler'

module Riml
  # lex code into tokens
  def self.lex(code)
    Lexer.new(code).tokenize
  end

  # parse code (or tokens) into nodes
  def self.parse(input, ast_rewriter = AST_Rewriter.new)
    unless input.is_a?(Array) || input.is_a?(String)
      raise ArgumentError, "input must be tokens or code, is #{input.class}"
    end
    Parser.new.parse(input, ast_rewriter)
  end

  # compile nodes (or tokens or code or file) into output code
  def self.compile(input, parser = Parser.new, compiler = Compiler.new)
    if input.is_a?(Nodes)
      nodes = input
    elsif input.is_a?(String) || input.is_a?(Array)
      nodes = parser.parse(input)
    elsif input.is_a?(File)
      source = input.read
      nodes = parser.parse(source)
    else
      raise ArgumentError, "input must be nodes, tokens or code, is #{input.class}"
    end
    output = compiler.compile(nodes)
    return output unless input.is_a?(File)
    write_file(output, input.path)
  ensure
    input.close if input.is_a?(File)
    process_compile_queue!(parser, compiler)
  end

  # expects `file_names` to be readable files
  def self.compile_files(*file_names)
    file_names.each do |file_name|
      f = File.open(file_name)
      # `compile` will close file handle
      compile(f)
    end
  end

  def self.source_path
    @source_path ||= Dir.getwd
  end
  def self.source_path=(path)
    @source_path = path
  end

  private

  # This is for when another file is sourced within a file we're compiling.
  # We have to share the same `ClassMap`, thus we have a queue for the compiler,
  # and we process this queue after each source we compile. We pass the same
  # parser instance to share Class state, as this state belongs to the
  # AST_Rewriter's `ClassMap`.
  def self.process_compile_queue!(parser, compiler)
    return true if compiler.compile_queue.empty?

    file_name = compiler.compile_queue.shift
    compile(File.open(File.join(Riml.source_path, file_name)), parser, Compiler.new)
    process_compile_queue!(parser, compiler)
  end

  FILE_HEADER = File.read(File.expand_path("../header.vim", __FILE__)) % VERSION.join('.')

  def self.write_file(output, file_name)
    file_basename = File.basename(file_name)
    unless File.extname(file_basename).empty?
      file_basename = file_basename.split(".").tap {|parts| parts.pop}.join(".")
    end
    File.open("#{file_basename}.vim", 'w') do |f|
      f.write FILE_HEADER + output
    end
  end

end
