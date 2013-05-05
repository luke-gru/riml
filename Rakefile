require File.expand_path('../lib/environment', __FILE__)
require 'rake/testtask'

task :default => :test
task :test => [:parser]

desc 'Run all tests (default)'
Rake::TestTask.new(:test) do |t|
  t.test_files = FileList['test/**/*_test.rb'].to_a
end

desc 'recreate lib/parser.rb from lib/grammar.y using racc'
task :parser do
  sh_in_libdir 'racc -o parser.rb grammar.y'
end

desc 'recreate lib/parser.rb with debug info from lib/grammar.y using racc'
task :debug_parser do
  sh_in_libdir 'racc --verbose -o parser.rb grammar.y'
end

def sh_in_libdir(cmd)
  Dir.chdir(File.expand_path("../lib", __FILE__)) do
    sh cmd
  end
end
