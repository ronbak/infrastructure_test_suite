require_relative '../../bin/provision.rb'
require 'rake/testtask'
require 'fileutils'
require 'pry-byebug'

Dir.mkdir 'output' unless Dir.exist?('output')
@config = JSON.parse(File.read('arm_templates/vms/sql/sql_iaasvms.config.json'))

task :build_envs do
  @config['environments'].each do |env_name, environment|
    if environment.dig('parameters', 'environment')
      #env_name = environment.dig('parameters', 'environment')
      if env_name.eql?('core')
        ENV['AZURE_STORAGE_ACCOUNT_KEY'] = ENV['SA_KEY_CORE']
      elsif env_name.eql?('prd')
        ENV['AZURE_STORAGE_ACCOUNT_KEY'] = ENV['SA_KEY_PRD']
      else
        ENV['AZURE_STORAGE_ACCOUNT_KEY'] = ENV['SA_KEY_NONPRD']
      end
      @options = OpenStruct.new
      @options.action = 'output'
      @options.output = "./output/#{env_name}_sql.json"
      @options.config = 'arm_templates/vms/sql/sql_iaasvms.config.json'
      @options.verbose = false
      @options.environment = env_name
      @options.complete_deployment = true
      @options.rules = nil
      @options.skip_deploy = false
      @options.prep_templates = false
      @options.location = 'WestEurope'
      @options.scope = nil

      provisioner = Provisioner.new(@options.to_h())
      provisioner.provision()
    end
  end
end

task :validate_templates do
  @config['environments'].each do |env_name, environment|
    if environment.dig('parameters', 'environment')
     # env_name = environment.dig('parameters', 'environment')
      ENV['CSRE_LOG_LEVEL'] = 'DEBUG'
      puts `pwd`
      puts `ls -lah`.split("\n")
      @options = OpenStruct.new
      @options.action = 'validate'
      @options.output = "./output/#{env_name}_sql.json"
      @options.config = 'arm_templates/vms/sql/sql_iaasvms.config.json'
      @options.verbose = false
      @options.environment = env_name
      @options.complete_deployment = true
      @options.rules = nil
      @options.skip_deploy = false
      @options.prep_templates = false
      @options.location = 'WestEurope'
      @options.scope = nil

      provisioner = Provisioner.new(@options.to_h())
      provisioner.provision()
    end
  end
end

task :move_nuget do
  FileUtils.cp('./arm_templates/vms/sql/Azure_VM.nuspec', './output/Azure_VM.nuspec')
end

task :build_sql_vms => [:build_envs, :validate_templates, :move_nuget] do
  puts "Building templates and testing them"
end
