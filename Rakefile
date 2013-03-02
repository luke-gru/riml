require File.expand_path('../lib/environment', __FILE__)
require 'rake/testtask'

task :default => :test
task :test => [:output_test_count]

desc 'Run all *_tests and *_specs (default)'
Rake::TestTask.new(:test) do |t|
  TEST_LIST = FileList['test/**/*_test.rb'].to_a
  t.test_files = TEST_LIST
end

task :output_test_count do
  puts "#{TEST_LIST.size} test files to run."
end
