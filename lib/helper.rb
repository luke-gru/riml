require File.expand_path('../../config/environment', __FILE__)
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
  def self.parse(input, rewrite_ast = true)
    unless input.is_a?(Array) || input.is_a?(String)
      raise ArgumentError, "input must be tokens or code, is #{input.class}"
    end
    Parser.new.parse(input, rewrite_ast)
  end

  # compile nodes (or tokens or code) into output code
  def self.compile(input)
    if input.is_a?(Nodes)
      nodes = input
    elsif input.is_a?(String) || input.is_a?(Array)
      nodes = parse(input)
    else
      raise ArgumentError, "input must be nodes, tokens or code, is #{input.class}"
    end
    Compiler.new.compile(nodes)
  end

  # expects `file_name` to be readable file
  def self.compile_file(file_name)
    input = File.read(file_name)
    output = compile(input)
    file_basename = File.basename(file_name)
    unless File.extname(file_basename).empty?
      file_basename = file_basename.split(".").tap {|parts| parts.pop}.join(".")
    end
    File.open("#{file_basename}.vim", 'w') do |f|
      f.write output
    end
  end
end
