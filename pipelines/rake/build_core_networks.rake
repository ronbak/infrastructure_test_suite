require_relative '../../bin/provision.rb'
require 'rake/testtask'

task :build_core do
  ENV['AZURE_STORAGE_ACCOUNT_KEY'] = ENV['SA_KEY_CORE']
  @options = OpenStruct.new
  @options.action = 'output'
  @options.output = './core_network.json'
  @options.config = 'arm_templates/networks/configs/networking_core.config.json'
  @options.verbose = false
  @options.environment = 'core'
  @options.complete_deployment = true
  @options.rules = nil
  @options.skip_deploy = false
  @options.prep_templates = true
  @options.location = 'WestEurope'
  @options.scope = nil

  provisioner = Provisioner.new(@options.to_h())
  provisioner.provision()
end

task :validate_templates do
  ENV['CSRE_LOG_LEVEL'] = 'DEBUG'
  puts `pwd`
  puts `ls -lah`.split("\n")
  @options = OpenStruct.new
  @options.action = 'validate'
  @options.output = './core_network.json'
  @options.config = 'arm_templates/networks/configs/networking_core.config.json'
  @options.verbose = false
  @options.environment = 'core'
  @options.complete_deployment = true
  @options.rules = nil
  @options.skip_deploy = false
  @options.prep_templates = true
  @options.location = 'WestEurope'
  @options.scope = nil

  provisioner = Provisioner.new(@options.to_h())
  provisioner.provision()
end

Rake::TestTask.new task :unit_tests do |t|
  t.libs.push "#{File.dirname(__FILE__)}/../../lib"
  t.test_files = FileList["#{File.dirname(__FILE__)}/../../tests/template/network_templates_tests.rb"]
  t.verbose = true
  t.warning = false
end

task :build_core_networks => [:build_core, :validate_templates, :unit_tests] do
  puts "Building templates and testing them"
end
