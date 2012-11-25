#!/usr/bin/env ruby

require File.expand_path('../../lib/riml', __FILE__)
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

    def lex(code)
      Riml.lex(code)
    end

    def parse(input, ast_rewriter = AST_Rewriter.new)
      Riml.parse(input, ast_rewriter)
    end

    def compile(input)
      Riml.compile(input)
    end

    def with_riml_source_path(path)
      old = Riml.source_path
      Riml.source_path = path
      Dir.chdir(path) { yield }
    ensure
      Riml.source_path = old
    end

    def with_file_cleanup(file_name)
      yield
    ensure
      full_path = File.join(Riml.source_path, file_name)
      File.delete(full_path) if File.exists?(full_path)
    end
  end
end
