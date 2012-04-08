#!/usr/bin/env ruby

require File.expand_path('../../config/environment', __FILE__)
require 'nodes'
require 'lexer'
require 'parser'
require 'compiler'

require 'minitest/autorun'

module Riml
  class TestCase < MiniTest::Unit::TestCase

    # taken from activesupport/testing/declarative
    def self.test(name, &block)
      test_name = "test_#{name.gsub(/\s+/,'_')}".to_sym
      defined = instance_method(test_name) rescue false
      raise "#{test_name} is already defined in #{self}" if defined
      if block_given?
        define_method(test_name, &block)
      else
        define_method(test_name) do
          flunk "No implementation provided for #{name}"
        end
      end
    end

    def lexer; Riml::Lexer.new end
    def parser; Riml::Parser.new end
    def compiler; Riml::Compiler.new end

    # lex code into tokens
    def lex(code)
      lexer.tokenize(code)
    end

    # parse code (or tokens) into nodes
    def parse(object)
      unless tokens?(object) || code?(object)
        raise ArgumentError, "object must be tokens or code, is #{object}"
      end
      parser.parse(object)
    end

    # compile nodes (or tokens or code) into output code
    def compile(object)
      if nodes?(object)
        nodes = object
      elsif tokens?(object) || code?(object)
        nodes = parser.parse(object)
      else
        raise ArgumentError, "object must be nodes, tokens or code, is #{object}"
      end
      compiler.compile(nodes)
    end

    private
    # is an array of arrays and first five inner arrays are all doubles
    def tokens?(object)
      Array === object and object[0..4].all? {|e| e.respond_to?(:size) and e.size == 2}
    end

    def code?(object)
      String === object
    end

    def nodes?(object)
      Nodes === object
    end

  end
end
