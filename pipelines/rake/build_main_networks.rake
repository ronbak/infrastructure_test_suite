require_relative '../../bin/provision.rb'
require 'rake/testtask'

task :build_nonprd do
  ENV['AZURE_STORAGE_ACCOUNT_KEY'] = ENV['SA_KEY_NONPRD']
  # Build eurw
  @options = OpenStruct.new
  @options.action = 'output'
  @options.output = './nonprd_network.json'
  @options.config = 'arm_templates/networks/configs/networking_master.config.json'
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

  # build eurn
  @options.output = './nonprd_eurn_network.json'
  @options.config = 'arm_templates/networks/configs/networking_eurn_master.config.json'
  @options.location = 'NorthEurope'
  @options.scope = nil

  provisioner = Provisioner.new(@options.to_h())
  provisioner.provision()
end

task :build_prd do
  ENV['AZURE_STORAGE_ACCOUNT_KEY'] = ENV['SA_KEY_PRD']
  # build eurw
  @options = OpenStruct.new
  @options.action = 'output'
  @options.output = './prd_network.json'
  @options.config = 'arm_templates/networks/configs/networking_master.config.json'
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

  # Build eurn
  @options.output = './prd_eurn_network.json'
  @options.config = 'arm_templates/networks/configs/networking_eurn_master.config.json'
  @options.location = 'NorthEurope'

  provisioner = Provisioner.new(@options.to_h())
  provisioner.provision()
end

task :validate_templates do
  ENV['CSRE_LOG_LEVEL'] = 'DEBUG'
  puts `pwd`
  puts `ls -lah`.split("\n")
  @options = OpenStruct.new
  @options.action = 'validate'
  @options.output = './nonprd_network.json'
  @options.config = 'arm_templates/networks/configs/networking_master.config.json'
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

  @options.output = './prd_network.json'
  @options.environment = 'prd'
  provisioner = Provisioner.new(@options.to_h())
  provisioner.provision()

  # eurn validation
  @options.output = './prd_eurn_network.json'
  @options.location = 'NorthEurope'
  @options.config = 'arm_templates/networks/configs/networking_eurn_master.config.json'
  @options.environment = 'prd'
  provisioner = Provisioner.new(@options.to_h())
  provisioner.provision()

  @options.output = './nonprd_eurn_network.json'
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
