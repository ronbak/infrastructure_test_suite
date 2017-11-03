require 'rake/testtask'
require 'git'


working_dir = '/tmp/infrastructure_test_suite/'

task :clone_tests do
  if File.directory?("#{working_dir}.git/")
    g = Git.open(working_dir, :log => Logger.new(STDOUT))
    g.checkout('master')
    g.pull
  else
    g = Git.clone('git://github.com/chudsonwr/infrastructure_test_suite.git', 'infrastructure_test_suite', :path => '/tmp/')
  end
end

Rake::TestTask.new task :unit_tests do |t|
  t.libs.push "#{working_dir}lib"
  t.test_files = FileList["#{working_dir}tests/template/templates_tests.rb"]
  t.verbose = true
  t.warning = false
end
