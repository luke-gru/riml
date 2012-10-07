require File.expand_path('../config/environment', __FILE__)
require 'rake/testtask'
require 'rake/clean'

task :default => :test
task :test => [:output_test_count]

desc 'Run all *_tests and *_specs (default)'
test = Rake::TestTask.new(:test) do |t|
  TEST_LIST = FileList['test/*_test.rb'].to_a
  SPEC_LIST = FileList['test/*_spec.rb'].to_a
  t.test_files = TEST_LIST
  t.test_files += SPEC_LIST unless SPEC_LIST.empty?
end

task :output_test_count do
  puts (TEST_LIST.count + SPEC_LIST.count).to_s + " test files to run."
end
