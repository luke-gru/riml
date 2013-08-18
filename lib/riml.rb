require 'pathname'
require 'fileutils'

require File.expand_path('../environment', __FILE__)
require 'nodes'
require 'lexer'
require 'parser'
require 'compiler'
require 'warning_buffer'

module Riml
  # lex code (String) into tokens (Array)
  def self.lex(code)
    Lexer.new(code).tokenize
  end

  # parse tokens (Array) or code (String) into AST (Nodes)
  def self.parse(input, ast_rewriter = AST_Rewriter.new, filename = nil)
    unless input.is_a?(Array) || input.is_a?(String)
      raise ArgumentError, "input must be tokens (Array) or code (String), " \
        "is #{input.inspect}"
    end
    Parser.new.parse(input, ast_rewriter, filename)
  end

  # compile AST (Nodes), tokens (Array), code (String) or object that returns
  # String from :read to output code (String). Writes file(s) if `input` is a
  # File.
  def self.compile(input, parser = Parser.new, compiler = Compiler.new)
    if input.is_a?(Nodes)
      nodes = input
    elsif input.is_a?(String) || input.is_a?(Array)
      nodes = parser.parse(input)
    elsif input.respond_to?(:read)
      source = input.read
      path = input.respond_to?(:path) ? input.path : nil
      nodes = parser.parse(source, AST_Rewriter.new, path)
    else
      raise ArgumentError, "input must be one of AST (Nodes), tokens (Array), " \
        "code (String) or respond_to?(:read), is #{input.inspect}"
    end

    if compiler.parser == parser
      compiling_cmdline_file = false
    else
      compiler.parser = parser
      compiling_cmdline_file = true
    end

    output = compiler.compile(nodes)

    if input.is_a?(File)
      write_file(compiler, output, input.path, compiling_cmdline_file)
    else
      output
    end
  ensure
    input.close if input.is_a?(File)
    process_compile_queue!(compiler)
  end

  # expects `filenames` (String) arguments, to be readable files. Optional options (Hash) as
  # last argument.
  def self.compile_files(*filenames)
    parser, compiler = Parser.new, Compiler.new

    if filenames.last.is_a?(Hash)
      opts = filenames.pop
      if dir = opts[:output_dir]
        compiler.output_dir = dir
      end
    end

    if filenames.size > 1
      threads = []
      filenames.each_with_index do |fname, i|
        if i.zero?
          _parser, _compiler = parser, compiler
        else
          _parser, _compiler = Parser.new, Compiler.new
          _compiler.output_dir = compiler.output_dir
        end
        threads << Thread.new do
          f = File.open(fname)
          compile(f, _parser, _compiler)
        end
      end
      threads.each {|t| t.join}
    elsif filenames.size == 1
      fname = filenames.first
      f = File.open(fname)
      # `compile` will close file handle
      compile(f, parser, compiler)
    else
      raise ArgumentError, "need filenames to compile"
    end
  ensure
    flush_warnings
  end

  # checks syntax of `input` (String).
  # lexes + parses without going through AST rewriting or compilation
  def self.check_syntax(input)
    raise ArgumentError.new(input) unless input.is_a?(String)
    parse(input, nil)
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

  def self.write_file(compiler, output, fname, cmdline_file = true)
    # writing out a file that's compiled from cmdline, output into output_dir
    output_dir = if cmdline_file
      compiler.output_dir || Dir.getwd
    # writing out a riml_source'd file
    else
      # absolute path for filename sent from cmdline or from riml_sourced files,
      # output to that same directory if no --output-dir option is set
      if fname[0] == File::SEPARATOR && !compiler.output_dir
        Pathname.new(fname).parent.to_s
      # relative path
      else
        File.join(compiler.output_dir || Dir.getwd, Pathname.new(fname).parent.to_s)
      end
    end
    basename_without_riml_ext = File.basename(fname).sub(/\.riml\Z/i, '')
    FileUtils.mkdir_p(output_dir) unless File.directory?(output_dir)
    full_path = File.join(output_dir, "#{basename_without_riml_ext}.vim")
    File.open(full_path, 'w') do |f|
      f.write FILE_HEADER + output
    end
  end

end
