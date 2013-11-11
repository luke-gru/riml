if RUBY_VERSION < '1.9'
  require 'rubygems'
end
gem 'minitest'
require 'minitest/autorun'
require 'mocha/setup'

$VERBOSE = 1
require File.expand_path('../../lib/riml', __FILE__)

module Riml
  class TestCase < MiniTest::Test

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

    alias assert_equal_orig assert_equal

    def assert_equal_debug(expected, actual)
      if expected == actual
        return assert_equal_orig(expected, actual)
      end

      STDERR.puts <<EOS
\nexpected:

#{expected.to_s.each_line.to_a.join}

actual:

#{actual.to_s.each_line.to_a.join}
EOS
      assert_equal_orig(expected, actual)
    end

    if ENV['DEBUG']
      alias assert_equal assert_equal_debug
    end

    def assert_riml_warning(expected_warning = /Warning:/i)
      _, err = capture_subprocess_io do
        yield
        Riml.send(:flush_warnings)
      end
      warnings = err.each_line.to_a
      if Regexp === expected_warning
        assert warnings.any? { |w| expected_warning =~ w }
      elsif expected_warning.respond_to?(:to_s)
        assert warnings.any? { |w| expected_warning.to_s == w }
      else
        raise ArgumentError
      end
    end

    def lex(code)
      Riml.lex(code)
    end

    def parse(input, ast_rewriter = AST_Rewriter.new)
      Riml.parse(input, ast_rewriter)
    ensure
      Riml::Parser.ast_cache.clear
    end

    def compile(input, options = {:readable => false})
      Riml.compile(input, options)
    ensure
      Riml.rewritten_ast_cache.clear
      Riml::Parser.ast_cache.clear
    end

    %w(source_path include_path).each do |path|
      define_method "with_riml_#{path}" do |*new_paths|
        begin
          old_path = Riml.send(path)
          Riml.send("#{path}=", new_paths, true)
          yield if block_given?
        ensure
          Riml.send("#{path}=", old_path, true)
        end
      end
    end

    def with_file_cleanup(*file_names)
      yield
    ensure
      file_names.each do |name|
        Riml.source_path.each do |path|
          full_path = File.join(path, name)
          if File.exists?(full_path)
            File.delete(full_path)
            break
          end
        end
      end
    end

    def with_mock_include_cache
      old_cache = Riml.include_cache
      new_cache = mock('include_cache')
      Riml.instance_variable_set("@include_cache", new_cache)
      yield new_cache
    ensure
      Riml.instance_variable_set("@include_cache", old_cache)
    end

  end
end

Riml::FileRollback.guard
Riml::FileRollback.trap(:INT, :QUIT, :KILL) do
  STDERR.print("rolling back files changes...\n")
  exit 1
end

all_files_before = Dir.glob('**/*')

MiniTest.after_run do
  all_files_after = Dir.glob('**/*')
  if all_files_after != all_files_before
    STDERR.puts "WARNING: test suite added/removed file(s). Diff: " \
      "#{all_files_after.to_set.difference(all_files_before.to_set).to_a}"
  end
end
