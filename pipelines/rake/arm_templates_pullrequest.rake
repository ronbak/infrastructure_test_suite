require_relative '../../bin/provision.rb'
require 'rake/testtask'

Rake::TestTask.new task :unit_tests do |t|
  t.libs.push "#{File.dirname(__FILE__)}/../../lib"
  t.test_files = FileList["#{File.dirname(__FILE__)}/../../tests/template/templates_tests.rb"]
  t.verbose = true
  t.warning = false
end
