require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new(:test) do |test|
  test.libs << "test" << "lib"
  test.pattern = 'test/plugin/test_*.rb'
  test.verbose = true
end

task :default => :test