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
  Dir.chdir(File.expand_path("../lib", __FILE__)) do
    sh 'racc -o parser.rb grammar.y'
  end
end
