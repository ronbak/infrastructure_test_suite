#!/usr/bin/env ruby
require 'optparse'
require 'ostruct'
require 'json'
require 'pry-byebug'
require_relative '../lib/WRAzureCredentials'
require_relative '../lib/WRAzureDeployer'
require_relative '../lib/WRConfigManager'
require_relative '../lib/CSRELogger'


# Shim for launching the WRAzureDeployer class from the command line
class Provisioner
  def initialize(opts = {})
    @opts = opts
    @metadata = wrmetadata()
    log_level = 'INFO'
    log_level = ENV['CSRE_LOG_LEVEL'] unless ENV['CSRE_LOG_LEVEL'].nil?
    @csrelog = CSRELogger.new(log_level, 'STDOUT')
    #@gh_raw_url = @metadata['cap_one_metadata']['github_raw_url']
  end

  def self.actions
    return ['deploy', 'delete', 'output']
  end

  def supported_action(action)
    return self.class.actions().any? { |a| a.casecmp(action).zero? }
  end

  def set_action(action)
    if supported_action(action)
      @opts[:action] = action.downcase()
      return true
    else
      puts format('[Provisioner] Unsupported Action: %s', action)
      return false
    end
  end

  def self.regions
    return ['WestEurope', 'NorthEurope']
  end

  def supported_region(region)
    return self.class.regions().any? { |a| a.casecmp(region).zero? }
  end

  def set_region(region)
    if supported_region(region)
      @opts[:region] = region.downcase()
      return true
    else
      puts format('[Provisioner] Unsupported Region: %s', region)
      return false
    end
  end

  def set_config(config)
    @opts[:config] = config
  end

  def provision()
    @csrelog.debug(@opts[:config])
    config_manager = WRConfigManager.new(config: @opts[:config])
    # config_manager.client_name
    # config_manager.rg_name(environment)
    # config_manager.parameters()
    # config_manager.template
    @csrelog.debug(@opts[:environment].to_s)
    if @opts[:complete_deployment] then @csrelog.info("Running deployment in 'Complete' mode, let's hope you meant that!!!") end
    options = {
      action: @opts[:action].to_s, 
      environment: @opts[:environment].to_s, 
      rg_name: config_manager.rg_name(@opts[:environment].to_s), 
      parameters: config_manager.parameters(), 
      template: config_manager.template(), 
      complete_deployment: @opts[:complete_deployment], 
      rules_template: @opts[:rules],
      skip_deploy: @opts[:skip_deploy],
      output: @opts[:output],
      prep_templates: @opts[:prep_templates]
    }
    deployer = WRAzureDeployer.new(options).process_deployment()
  end
end

def missing_args()
  raise OptionParser::MissingArgument, "You're missing the --config ConfigFile option" if @options.config.nil?
end

def parse_args(args)
  opt_parser = OptionParser.new do |opts|
    opts.banner = 'Usage: provision.rb [options]'
    opts.on('--action [TYPE]', Provisioner.actions(),
            'Select action type (deploy, delete)') do |a|
      @options.action = a
    end
    opts.on('-c', '--config PATH', 'Config File path argument or JSON config as String') do |cfg|
      @options.config = cfg
    end
    opts.on('-r', '--rules PATH', 'NSG Rules template file path argument or JSON String') do |rules|
      @options.rules = rules
    end
    opts.on('--environment [TYPE]', [:production, :dev, :services, :preprod, :sandbox],
            "Environment to deploy your template in to") do |environment|
      @options.environment = environment
    end
    opts.on("--complete", "runs an Azure ARm Complete deployment, use wisely", "true or false.") do |complete_deployment|
      @options.complete_deployment = complete_deployment
    end
    opts.on("--skip_deploy", "Skips the main deployment step, useful for testing or validating configs", "true or false.") do |skip_deploy|
      @options.skip_deploy = skip_deploy
    end
    opts.on("--prep_templates", "Uploads linked templates to Azure Storage", "true or false.") do |prep_templates|
      @options.prep_templates = prep_templates
    end
    opts.on('-o', '--output PATH', 'Outputs the created ARM Template to the parth specified and does not run the deployment') do |output|
      @options.output = output
    end 
  end

  opt_parser.parse!(args)
  missing_args()
end

#--------------------------------------------
# Execution point...
#--------------------------------------------
if __FILE__ == $PROGRAM_NAME
  # Setup command line arguments
  @options = OpenStruct.new
  @options.action = 'create'
  @options.config = nil
  @options.verbose = false
  @options.environment = nil
  @options.complete_deployment = false
  @options.rules = nil
  @options.skip_deploy = false
  @options.prep_templates = false
  parse_args(ARGV)

  provisioner = Provisioner.new(@options.to_h())
  provisioner.provision()
end



# environment = 'dev'
# config = '../configs/jenkins2.config
