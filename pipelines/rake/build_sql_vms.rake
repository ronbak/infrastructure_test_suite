require_relative '../../bin/provision.rb'
require 'rake/testtask'
require 'fileutils'

task :build_dev do
  Dir.mkdir 'output' unless Dir.exist?('output')
  ENV['AZURE_STORAGE_ACCOUNT_KEY'] = ENV['SA_KEY_NONPRD']
  # Build eurw
  @options = OpenStruct.new
  @options.action = 'output'
  @options.output = './output/dev_sql.json'
  @options.config = 'arm_templates/vms/sql/sql_iaasvms.config.json'
  @options.verbose = false
  @options.environment = 'dev'
  @options.complete_deployment = true
  @options.rules = nil
  @options.skip_deploy = false
  @options.prep_templates = false
  @options.location = 'WestEurope'
  @options.scope = nil

  provisioner = Provisioner.new(@options.to_h())
  provisioner.provision()
end

task :build_prd do
  ENV['AZURE_STORAGE_ACCOUNT_KEY'] = ENV['SA_KEY_PRD']
  # Build eurw
  @options = OpenStruct.new
  @options.action = 'output'
  @options.output = './output/prd_sql.json'
  @options.config = 'arm_templates/vms/sql/sql_iaasvms.config.json'
  @options.verbose = false
  @options.environment = 'prd'
  @options.complete_deployment = true
  @options.rules = nil
  @options.skip_deploy = false
  @options.prep_templates = false
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
  @options.output = './output/dev_sql.json'
  @options.config = 'arm_templates/vms/sql/sql_iaasvms.config.json'
  @options.verbose = false
  @options.environment = 'dev'
  @options.complete_deployment = true
  @options.rules = nil
  @options.skip_deploy = false
  @options.prep_templates = false
  @options.location = 'WestEurope'
  @options.scope = nil

  provisioner = Provisioner.new(@options.to_h())
  provisioner.provision()

  @options.output = './output/prd_sql.json'
  @options.environment = 'prd'
  provisioner = Provisioner.new(@options.to_h())
  provisioner.provision()
end

task :move_nuget do
  FileUtils.cp('./arm_templates/vms/sql/Azure_VM.nuspec', './output/Azure_VM.nuspec')
end

task :build_sql_vms => [:build_dev, :build_prd, :validate_templates, :move_nuget] do
  puts "Building templates and testing them"
end
