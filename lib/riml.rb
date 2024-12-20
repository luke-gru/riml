require 'pathname'
require 'fileutils'
require 'ostruct'

if RUBY_VERSION < '1.9'
  require 'thread'
end

require File.expand_path('../riml/environment', __FILE__)
require 'riml/lexer'
require 'riml/nodes'
require 'riml/parser'
require 'riml/compiler'
require 'riml/warning_buffer'
require 'riml/include_cache'
require 'riml/path_cache'
require 'riml/rewritten_ast_cache'
require 'riml/backtrace_filter'
require 'riml/file_rollback'

module Riml

  DEFAULT_COMPILE_OPTIONS = { :readable => true }
  DEFAULT_COMPILE_FILES_OPTIONS = DEFAULT_COMPILE_OPTIONS.merge(
    :output_dir => nil
  )
  DEFAULT_PARSE_OPTIONS = {
    :allow_undefined_global_classes => false,
    :include_reordering => true
  }

  EXTRACT_PARSE_OPTIONS   = lambda { |k,_| DEFAULT_PARSE_OPTIONS.keys.include?(k.to_sym) }
  EXTRACT_COMPILE_OPTIONS = lambda { |k,_| DEFAULT_COMPILE_OPTIONS.keys.include?(k.to_sym) }
  EXTRACT_COMPILE_FILES_OPTIONS = lambda { |k,_| DEFAULT_COMPILE_FILES_OPTIONS.keys.include?(k.to_sym) }

  FILENAME_OPTION_KEYS = [:commandline_filename, :sourced_filename]
  EXTRACT_FILENAME_OPTIONS = lambda { |k,_| FILENAME_OPTION_KEYS.include?(k.to_sym) }

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
    parse_options = Hash[options.select(&EXTRACT_PARSE_OPTIONS)]
    compile_options = Hash[options.select(&EXTRACT_COMPILE_OPTIONS)]
    parser = Parser.new
    parser.options = DEFAULT_PARSE_OPTIONS.merge(parse_options)
    compiler = Compiler.new
    compiler.options = DEFAULT_COMPILE_OPTIONS.merge(compile_options)
    filename_options = Hash[options.select(&EXTRACT_FILENAME_OPTIONS)]
    do_compile(input, parser, compiler, filename_options)
  end

  # compile AST (Nodes), tokens (Array), code (String) or object that returns
  # String from :read to output code (String). Writes file(s) if `input` is a
  # File.
  def self.do_compile(input, parser = Parser.new, compiler = Compiler.new, filename_options = {})
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

    compiler.parser = parser

    # This is to avoid cases where the file we're compiling from the
    # commandline gets recompiled but put in a different location because
    # it's also sourced, and `Riml.source_path` is set to a non-default value.
    if input.is_a?(File)
      pathname = Pathname.new(input.path)
      full_path =
        if pathname.absolute?
          pathname.to_s
        else
          File.expand_path(input.path, compiler.output_dir || Dir.getwd)
        end
      compiler.sourced_files_compiled << full_path
    end

    output = compiler.compile(nodes)

    if input.is_a?(File)
      write_file(compiler, output, input.path, filename_options)
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
      compile_options = Hash[options.select(&EXTRACT_COMPILE_FILES_OPTIONS)]
      parse_options = Hash[options.select(&EXTRACT_PARSE_OPTIONS)]
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
              do_compile(f, _parser, _compiler, :commandline_filename => fname)
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
      with_file_rollback { do_compile(f, parser, compiler, :commandline_filename => fname) }
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
    Parser.ast_cache.clear
  end

  # if error is thrown, all files that were created will be rolled back
  # to their previous state. If the file existed previously, it will be
  # the same as it was. If the file didn't exist, it will be removed if
  # it was created.
  def self.with_file_rollback(&block)
    FileRollback.guard(&block)
  end

  class << self
    attr_accessor :warnings, :debug
  end
  self.warnings = true
  self.debug = false

  # @return OpenStruct|nil
  def self.config
    @config
  end

  # possible values: OpenStruct|nil
  def self.config=(config)
    unless config.nil? || OpenStruct === config
      raise ArgumentError, "config must be OpenStruct or NilClass, is #{config.class}"
    end
    @config = config
  end
  self.config = nil # avoid ivar warnings

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
      unless File.directory?(dir)
        raise UserArgumentError, "Error trying to set #{name.to_s}. " \
          "Directory #{dir.inspect} doesn't exist"
      end
    end
    instance_variable_set("@#{name}", path)
    cache_files_in_path(path, force_cache_bust)
    path
  end
  self.source_path  = nil  # avoid ivar warnings
  self.include_path = nil  # avoid ivar warnings

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
    while paths = compiler.compile_queue.shift
      basename, full_path = *paths
      unless compiler.sourced_files_compiled.include?(full_path)
        compiler.sourced_files_compiled << full_path
        do_compile(File.open(full_path), compiler.parser, compiler, :sourced_filename => basename)
      end
    end
  end

  FILE_HEADER = File.read(File.expand_path("../riml/header.vim", __FILE__)) % VERSION.join('.')
  INCLUDE_COMMENT_FMT = File.read(File.expand_path("../riml/included.vim", __FILE__))
  GET_SID_FUNCTION_SRC = File.read(File.expand_path("../riml/get_sid_function.vim", __FILE__))

  # Files are written following these rules:
  # If a filename is given from the commandline,
  #   1) if the filename is absolute, output it to the directory in which the file resides
  #   2) if there's an `output_dir` given, output the file to that directory
  #   3) otherwise, output it into pwd
  # If a filename is sourced,
  #   1) if the filename is absolute, output it to the directory in which the file resides
  #   2) otherwise, output it to the directory in which the `riml` file is found, checking `Riml.source_path`
  def self.write_file(compiler, output, full_path, filename_options = {})
    fname = filename_options[:commandline_filename] || filename_options[:sourced_filename]
    fname or raise ArgumentError, "must pass correct filename_options"
    # writing out a file that's compiled from cmdline, output into output_dir
    output_dir = if filename_options[:commandline_filename]
      compiler.output_dir || Dir.getwd
    # writing out a riml_source'd file
    else
      # absolute path for filename sent from riml_sourced files,
      # output to that same directory if no --output-dir option is set
      if full_path[0, 1] == File::SEPARATOR && !compiler.output_dir
        Pathname.new(full_path).parent.to_s
      # relative path, join it with output_dir
      else
        rel_dir = Pathname.new(full_path).parent.to_s
        File.join(compiler.output_dir || Dir.getwd, rel_dir)
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
