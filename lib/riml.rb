require 'pathname'

require File.expand_path('../environment', __FILE__)
require 'nodes'
require 'lexer'
require 'parser'
require 'compiler'
require 'warning_buffer'

module Riml
  # lex code into tokens
  def self.lex(code)
    Lexer.new(code).tokenize
  end

  # parse code (or tokens) into nodes
  def self.parse(input, ast_rewriter = AST_Rewriter.new, filename = nil)
    unless input.is_a?(Array) || input.is_a?(String)
      raise ArgumentError, "input must be tokens or code, is #{input.class}"
    end
    Parser.new.parse(input, ast_rewriter, filename)
  end

  # compile nodes (or tokens or code or file) into output code
  def self.compile(input, parser = Parser.new, compiler = Compiler.new)
    if input.is_a?(Nodes)
      nodes = input
    elsif input.is_a?(String) || input.is_a?(Array)
      nodes = parser.parse(input)
    elsif input.is_a?(File)
      source = input.read
      nodes = parser.parse(source, AST_Rewriter.new, input.path)
    else
      raise ArgumentError, "input must be nodes, tokens, code or file, is #{input.class}"
    end
    compiler.parser = parser
    output = compiler.compile(nodes)
    if input.is_a?(File)
      write_file(output, input.path)
    else
      output
    end
  ensure
    input.close if input.is_a?(File)
    process_compile_queue!(compiler)
  end

  # expects `file_names` to be readable files
  def self.compile_files(*filenames)
    if filenames.size > 1
      threaded_compile_files(*filenames)
    elsif filenames.size == 1
      fname = filenames.first
      f = File.open(fname)
      # `compile` will close file handle
      compile(f)
    else
      raise ArgumentError, "need filenames to compile"
    end
  ensure
    flush_warnings
  end

  # checks syntax of `input` (lexes + parses) without going through ast rewriting or compilation
  def self.check_syntax(input)
    raise ArgumentError.new(input) unless input.is_a?(String)
    parse(input, false)
    true
  end

  def self.check_syntax_files(*filenames)
    filenames.each do |fname|
      File.open(fname) {|f| check_syntax(f.read)}
    end
    true
  end

  def self.source_path
    get_path(:source_path)
  end

  def self.source_path=(path)
    set_path(:source_path, path)
  end

  def self.include_path
    get_path(:include_path)
  end

  def self.include_path=(path)
    set_path(:include_path, path)
  end

  def self.warn(warning)
    warning_buffer << warning
  end

  class << self
    attr_accessor :warnings
  end
  self.warnings = true

  private

  def self.flush_warnings
    if warnings
      warning_buffer.flush
    else
      warning_buffer.clear
    end
  end

  def self.warning_buffer
    @warning_buffer ||= WarningBuffer.new
  end

  def self.set_path(name, path)
    return instance_variable_set("@#{name}", nil) if path.nil?
    path = path.split(':') if path.is_a?(String)
    path.each do |dir|
      unless Dir.exists?(dir)
        raise UserArgumentError, "Error trying to set #{name.to_s}. " \
          "Directory #{dir.inspect} doesn't exist"
      end
    end
    instance_variable_set("@#{name}", path)
  end
  self.source_path  = nil  # eliminate ivar warnings
  self.include_path = nil  # eliminate ivar warnings

  def self.get_path(name)
    ivar = instance_variable_get("@#{name}")
    return ivar if ivar
    # RIML_INCLUDE_PATH or RIML_SOURCE_PATH
    val = if (path = ENV["RIML_#{name.to_s.upcase}"])
      path
    else
      [Dir.getwd]
    end
    set_path(name, val)
  end

  def self.threaded_compile_files(*filenames)
    threads = []
    filenames.each do |fname|
      threads << Thread.new do
        f = File.open(fname)
        compile(f)
      end
    end
    threads.each {|t| t.join}
  end

  # This is for when another file is sourced within a file we're compiling.
  def self.process_compile_queue!(compiler)
    while full_path = compiler.compile_queue.shift
      unless compiler.sourced_files_compiled.include?(full_path)
        compiler.sourced_files_compiled << full_path
        compile(File.open(full_path), compiler.parser, compiler)
      end
    end
  end

  FILE_HEADER = File.read(File.expand_path("../header.vim", __FILE__)) % VERSION.join('.')
  INCLUDE_COMMENT_FMT = File.read(File.expand_path("../included.vim", __FILE__))

  def self.write_file(output, fname)
    # absolute path, output into same directory as file
    dir = if fname[0] == File::SEPARATOR
      Pathname.new(fname).parent.to_s
    # relative path, output into current working directory
    else
      Dir.getwd
    end
    basename_without_riml_ext = File.basename(fname).sub(/\.riml\Z/i, '')
    full_path = File.join(dir, "#{basename_without_riml_ext}.vim")
    File.open(full_path, 'w') do |f|
      f.write FILE_HEADER + output
    end
  end

end
