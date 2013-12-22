if RUBY_VERSION < '1.9'
  require 'rubygems'
end

require File.expand_path('../lib/riml/environment', __FILE__)
require 'rake/testtask'
require 'bundler/setup'
require 'bundler/gem_tasks'

task :default => :test
task :test => [:parser]

desc 'Run all tests (default)'
Rake::TestTask.new(:test) do |t|
  t.test_files = FileList['test/**/*_test.rb'].to_a
end

desc 'Run benchmarks'
task :bench => [:parser] do
  load File.expand_path('../benchmarks/run', __FILE__)
end

desc 'recreate lib/parser.rb from lib/grammar.y using racc'
task :parser do
  in_libdir { sh 'racc -o parser.rb grammar.y' }
end

desc 'recreate lib/parser.rb with debug info from lib/grammar.y using racc'
task :debug_parser do
  in_libdir { sh 'racc --verbose -o parser.rb grammar.y' }
end

def in_libdir
  Dir.chdir(File.expand_path("../lib/riml", __FILE__)) do
    yield
  end
end
