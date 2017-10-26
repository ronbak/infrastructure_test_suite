require_relative '../../bin/provision.rb'
require 'rake/testtask'

task :build_nonprd do
  ENV['AZURE_STORAGE_ACCOUNT_KEY'] = ENV['SA_KEY_NONPRD']
  puts ENV['AZURE_STORAGE_ACCOUNT_KEY']
  @options = OpenStruct.new
  @options.action = 'output'
  @options.output = './nonprd_networks.json'
  @options.config = ENV['config_path']
  @options.verbose = false
  @options.environment = 'nonprd'
  @options.complete_deployment = true
  @options.rules = nil
  @options.skip_deploy = false
  @options.prep_templates = true
  @options.location = 'WestEurope'
  @options.scope = nil

  provisioner = Provisioner.new(@options.to_h())
  provisioner.provision()
end

task :build_prd do
  ENV['AZURE_STORAGE_ACCOUNT_KEY'] = ENV['SA_KEY_PRD']
  @options = OpenStruct.new
  @options.action = 'output'
  @options.output = './prd_networks.json'
  @options.config = ENV['config_path']
  @options.verbose = false
  @options.environment = 'prd'
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
  @options = OpenStruct.new
  @options.action = 'validate'
  @options.output = './nonprd_networks.json'
  @options.config = ENV['config_path']
  @options.verbose = false
  @options.environment = 'nonprd'
  @options.complete_deployment = true
  @options.rules = nil
  @options.skip_deploy = false
  @options.prep_templates = true
  @options.location = 'WestEurope'
  @options.scope = nil

  provisioner = Provisioner.new(@options.to_h())
  provisioner.provision()

  @options.output = './nonprd_networks.json'
  @options.environment = 'nonprd'
  provisioner = Provisioner.new(@options.to_h())
  provisioner.provision()
end

Rake::TestTask.new task :unit_tests do |t|
  t.libs.push "#{File.dirname(__FILE__)}/../../lib"
  t.test_files = FileList["#{File.dirname(__FILE__)}/../../tests/template/network_templates_tests.rb"]
  t.verbose = true
  t.warning = false
end

task :build_main_networks => [:build_nonprd, :build_prd, :validate_templates, :unit_tests] do
  puts "Building templates and testing them"
end



