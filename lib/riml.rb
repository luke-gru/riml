require 'pathname'
require 'fileutils'

require File.expand_path('../riml/environment', __FILE__)
require 'riml/nodes'
require 'riml/lexer'
require 'riml/parser'
require 'riml/compiler'
require 'riml/warning_buffer'
require 'riml/include_cache'
require 'riml/path_cache'
require 'riml/rewritten_ast_cache'
require 'riml/file_rollback'

module Riml

  DEFAULT_COMPILE_OPTIONS = { :readable => true }
  DEFAULT_COMPILE_FILES_OPTIONS = DEFAULT_COMPILE_OPTIONS.merge(
    :output_dir => nil
  )
  DEFAULT_PARSE_OPTIONS = { :allow_undefined_global_classes => false }

  EXTRACT_PARSE_OPTIONS   = lambda { |k,_| DEFAULT_PARSE_OPTIONS.keys.include?(k.to_sym) }
  EXTRACT_COMPILE_OPTIONS = lambda { |k,_| DEFAULT_COMPILE_OPTIONS.keys.include?(k.to_sym) }
  EXTRACT_COMPILE_FILES_OPTIONS = lambda { |k,_| DEFAULT_COMPILE_FILES_OPTIONS.keys.include?(k.to_sym) }

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

  def self.compile(input, options = {})
    parse_options = options.select(&EXTRACT_PARSE_OPTIONS)
    compile_options = options.select(&EXTRACT_COMPILE_OPTIONS)
    parser = Parser.new
    parser.options = DEFAULT_PARSE_OPTIONS.merge(parse_options)
    compiler = Compiler.new
    compiler.options = DEFAULT_COMPILE_OPTIONS.merge(compile_options)
    do_compile(input, parser, compiler)
  end

  # compile AST (Nodes), tokens (Array), code (String) or object that returns
  # String from :read to output code (String). Writes file(s) if `input` is a
  # File.
  def self.do_compile(input, parser = Parser.new, compiler = Compiler.new)
    if input.is_a?(Nodes)
      nodes = input
    elsif input.is_a?(String) || input.is_a?(Array)
      nodes = parser.parse(input)
    elsif input.respond_to?(:read)
      source = input.read
      path = input.respond_to?(:path) ? input.path : nil
      nodes = parser.parse(source, parser.ast_rewriter || AST_Rewriter.new, path)
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

  # expects `filenames` (String) arguments, to be readable files.
  # Optional options (Hash) as last argument.
  def self.compile_files(*filenames)
    filenames = filenames.dup
    parser, compiler = Parser.new, Compiler.new

    # extract parser and compiler options from last argument, or use default
    # options
    if filenames.last.is_a?(Hash)
      options = filenames.pop
      compile_options = options.select(&EXTRACT_COMPILE_FILES_OPTIONS)
      parse_options = options.select(&EXTRACT_PARSE_OPTIONS)
      compiler.options = DEFAULT_COMPILE_FILES_OPTIONS.merge(compile_options)
      parser.options = DEFAULT_PARSE_OPTIONS.merge(parse_options)
    else
      compiler.options = DEFAULT_COMPILE_FILES_OPTIONS.dup
      parser.options = DEFAULT_PARSE_OPTIONS.dup
    end

    filenames.uniq!
    # compile files using one thread per file, max 4 threads at once
    if filenames.size > 1
      threads = []
      with_file_rollback do
        while filenames.any?
          to_compile = filenames.shift(4)
          to_compile.each do |fname|
            _parser, _compiler = Parser.new, Compiler.new
            _compiler.options = compiler.options.dup
            _parser.options = parser.options.dup
            threads << Thread.new do
              f = File.open(fname)
              # `do_compile` will close file handle
              do_compile(f, _parser, _compiler)
            end
          end
          threads.each(&:join)
          threads.clear
        end
      end
    elsif filenames.size == 1
      fname = filenames.first
      f = File.open(fname)
      # `do_compile` will close file handle
      with_file_rollback { do_compile(f, parser, compiler) }
    else
      raise ArgumentError, "need filenames to compile"
    end
    true
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
  def self.source_path=(path, force_cache_bust = false)
    set_path(:source_path, path, force_cache_bust)
  end

  def self.include_path
    get_path(:include_path)
  end
  def self.include_path=(path, force_cache_bust = false)
    set_path(:include_path, path, force_cache_bust)
  end

  def self.warn(warning)
    warning_buffer << warning
  end

  def self.include_cache
    @include_cache
  end
  # initialize non-lazily because ||= isn't thread-safe and
  # this is used across threads
  @include_cache = IncludeCache.new

  def self.path_cache
    @path_cache
  end
  @path_cache = PathCache.new

  def self.rewritten_ast_cache
    @rewritten_ast_cache
  end
  @rewritten_ast_cache = RewrittenASTCache.new

  def self.clear_caches
    @include_cache.clear
    @path_cache.clear
    @rewritten_ast_cache.clear
  end

  # if error is thrown, all files that were created will be rolled back
  # to their previous state. If the file existed previously, it will be
  # the same as it was. If the file didn't exist, it will be removed if
  # it was created.
  def self.with_file_rollback(&block)
    FileRollback.guard(&block)
  end

  # turn warnings on/off
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
    @warning_buffer
  end
  # initialize non-lazily because ||= isn't thread-safe and
  # this is used across threads
  @warning_buffer = WarningBuffer.new

  def self.set_path(name, path, force_cache_bust = false)
    return instance_variable_set("@#{name}", nil) if path.nil?
    path = path.split(':') if path.is_a?(String)
    path.each do |dir|
      unless Dir.exists?(dir)
        raise UserArgumentError, "Error trying to set #{name.to_s}. " \
          "Directory #{dir.inspect} doesn't exist"
      end
    end
    instance_variable_set("@#{name}", path)
    cache_files_in_path(path, force_cache_bust)
    path
  end
  self.source_path  = nil  # eliminate ivar warnings
  self.include_path = nil  # eliminate ivar warnings

  def self.cache_files_in_path(path, force_cache_bust = false)
    @path_cache[path] = nil if force_cache_bust
    @path_cache[path] || @path_cache.cache(path)
  end

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
        do_compile(File.open(full_path), compiler.parser, compiler)
      end
    end
  end

  FILE_HEADER = File.read(File.expand_path("../riml/header.vim", __FILE__)) % VERSION.join('.')
  INCLUDE_COMMENT_FMT = File.read(File.expand_path("../riml/included.vim", __FILE__))
  GET_SID_FUNCTION_SRC = File.read(File.expand_path("../riml/get_sid_function.vim", __FILE__))

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
    # if a function definition is at the end of a file and the :readable compiler
    # option is `true`, there will be 2 NL at EOF
    if output[-2..-1] == "\n\n"
      output.chomp!
    end
    FileRollback.creating_file(full_path)
    File.open(full_path, 'w') do |f|
      f.write FILE_HEADER + output
    end
  end

end
