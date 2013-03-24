require File.expand_path('../lib/environment', __FILE__)
require 'rake/testtask'

task :default => :test
task :test => [:output_test_count]

desc 'Run all tests (default)'
Rake::TestTask.new(:test) do |t|
  TEST_LIST = FileList['test/**/*_test.rb'].to_a
  t.test_files = TEST_LIST
end

desc 'recreate lib/parser.rb from lib/grammar.y using racc'
task :parser do
  Dir.chdir(File.expand_path("../lib", __FILE__)) do
    sh 'racc -o parser.rb grammar.y'
  end
end

task :output_test_count do
  puts "#{TEST_LIST.size} test files to run."
end
