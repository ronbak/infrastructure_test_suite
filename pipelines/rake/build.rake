require_relative '../../bin/provision.rb'
require 'rake/testtask'
require 'fileutils'
require 'pry-byebug'

@cl_options = {}
@cl_options[:prep_templates] = true
OptionParser.new do |opts|
  opts.banner = "Usage: rake build [options]"
  opts.on("-c", "--config ARG", String) { |config| @cl_options[:config] = config }
  opts.on("-o", "--output ARG", String) { |output| @cl_options[:output] = output }
  opts.on("-p", "--prep_templates ARG", String) { |prep_templates| @cl_options[:prep_templates] = prep_templates }
end.parse!

Dir.mkdir 'output' unless Dir.exist?('output')
@config = JSON.parse(File.read(@cl_options[:config]))

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
      @options.output = "#{@cl_options[:output]}/#{env_name}_#{@cl_options[:config].split('/')[-1].split('.')[0]}"
      @options.config = @cl_options[:config]
      @options.verbose = false
      @options.environment = env_name
      @options.complete_deployment = true
      @options.rules = nil
      @options.skip_deploy = false
      @options.prep_templates = @cl_options[:prep_templates]
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
      @options.output = "#{@cl_options[:output]}/#{env_name}_#{@cl_options[:config].split('/')[-1].split('.')[0]}"
      @options.config = @cl_options[:config]
      @options.verbose = false
      @options.environment = env_name
      @options.complete_deployment = true
      @options.rules = nil
      @options.skip_deploy = false
      @options.prep_templates = @cl_options[:prep_templates]
      @options.location = 'WestEurope'
      @options.scope = nil

      provisioner = Provisioner.new(@options.to_h())
      provisioner.provision()
    end
  end
end

task :move_nuget do
  FileUtils.cp(@cl_options[:config].split(@cl_options[:config].split('/')[-1])[0] + '/Azure_VM.nuspec', @cl_options[:output] + '/Azure_VM.nuspec')
end

task :build => [:build_envs, :validate_templates, :move_nuget] do
  puts "Building templates and testing them"
end
