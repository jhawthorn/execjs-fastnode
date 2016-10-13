require "bundler/gem_tasks"
require "rake/testtask"

task :test do
  ENV["EXECJS_RUNTIME"] = 'FastNode'
end
Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList['test/shim.rb', 'test/**/*_test.rb', 'test/test_execjs.rb']
end

task :default => :test
