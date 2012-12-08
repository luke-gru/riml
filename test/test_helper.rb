#!/usr/bin/env ruby

$VERBOSE = 1

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

    # `capture_subprocess_io` is available in new versions of MiniTest
    MiniTest::Assertions.class_eval do
      def capture_subprocess_io
        require 'tempfile'

        captured_stdout, captured_stderr = Tempfile.new("out"), Tempfile.new("err")

        orig_stdout, orig_stderr = $stdout.dup, $stderr.dup
        $stdout.reopen captured_stdout
        $stderr.reopen captured_stderr

        begin
          yield

          $stdout.rewind
          $stderr.rewind

          [captured_stdout.read, captured_stderr.read]
        ensure
          captured_stdout.unlink
          captured_stderr.unlink
          $stdout.reopen orig_stdout
          $stderr.reopen orig_stderr
        end
      end
    end unless MiniTest::Assertions.instance_methods.include?(:capture_subprocess_io)

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

    def with_file_cleanup(*file_names)
      yield
    ensure
      file_names.each do |name|
        full_path = File.join(Riml.source_path, name)
        File.delete(full_path) if File.exists?(full_path)
      end
    end
  end
end
