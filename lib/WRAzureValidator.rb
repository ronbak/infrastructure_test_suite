require 'azure_mgmt_resources'
require_relative 'WRAzureCredentials'
require_relative 'WRAzureResourceManagement'
require_relative 'CSRELogger'
require_relative 'WRAzureNsgRulesMgmt'
require_relative 'WRAzureTemplateManagement'
require_relative 'WRSubnetsArrayBuilder'
require_relative 'WRAzureTemplateValidator'
require_relative 'WRResourceGroupsManagement'
require 'pry-byebug'

# Main orchestration class for building the deployment object and sending to Azure
class WRAzureValidator

  def initialize(environment: nil, output: nil, rg_name: nil, config: nil)
    log_level = 'INFO'
    log_level = ENV['CSRE_LOG_LEVEL'] unless ENV['CSRE_LOG_LEVEL'].nil?
    @csrelog = CSRELogger.new(log_level, 'STDOUT')
    # Boolean deployment mode switch
    @environment = wrenvironmentdata(environment)['name']
    @metadata = wrmetadata()
    @landscape = environment
    @rg_name = rg_name
    @output = output
    @config_manager = config
    options = {environment: @environment}
    @credentials = WRAzureCredentials.new(options).authenticate()
    @client = WRAzureResourceManagement.new(environment: @environment, landscape: @landscape)
    @resource_group_location = @config_manager.parameters.dig('location', 'value')
    @resource_group_location = 'WestEurope' if @resource_group_location.nil?
  end

  # Main orchestration method
  def validate()
    # creates RG if environment specific tags exist, and permits access to octopus-dev-app-wr SPN as custom contributor role
    if @config_manager.tags(@landscape)
      @csrelog.debug("Creating or updating the resource group: #{@rg_name}")
      @client.create_resource_group(@resource_group_location, @rg_name, @config_manager.tags(@landscape))
      rg_client = WRResourceGroupsManagement.new(config: @config_manager.config, environment: @environment)
      au_client = rg_client.create_azure_au_client(@environment)
      rg_client.assign_usergroup_rg(au_client, wrmetadata().dig('global', 'service_principals', 'octopus-dev-app-wr'), @rg_name, 'cust-Contributor-no-pip-sa-rg')
    end
    arm_template_files = find_params_file(@output)
    templates_to_test = arm_template_files['templates']
    parameters_file = arm_template_files['parameters']
    results = {}
    @csrelog.debug("Testing the following templates: #{templates_to_test}\nUsing the following parameters file: #{parameters_file}\n")
    templates_to_test.each do |template|
      @csrelog.debug("\nTesting template: #{template}")
      result = WRAzureTemplateValidator.new(template: template, parameters: parameters_file, environment: @environment, rg_name: @rg_name).valid_template?
      @csrelog.debug("Result: #{result}\n")
      results[template] = result
    end
    @csrelog.fatal("One or more of your templates failed validation: #{results}") if results.values.include?(false)
    exit 1 if results.values.include?(false)
    @csrelog.debug("Your templates passed validation: #{results}")
    return results
  end
      
  def find_params_file(output_path)
    files_path = File.dirname(output_path)
    files = Dir["#{files_path}/*.json"]
    templates_to_test = files.select { |file| !file.include?('.parameters.') && file.split('/')[-1].split('.')[0].eql?(output_path.split('/')[-1].split('.')[0])}
    templates_to_test.each do |template|
      files.delete(template)
    end
    parameters_file = files.select { |file| file.include?('.parameters.') && file.split('/')[-1].split('.')[0].eql?(output_path.split('/')[-1].split('.')[0])}
    parameters_file = parameters_file[0] if parameters_file.count.eql?(1)
    parameters_file = parameters_file.find { |file| file.include?(@landscape) } if parameters_file.class.eql?(Array)
    parameters_file = files[0] if parameters_file.nil? && files.count == 1
    return {'templates' => templates_to_test, 'parameters' => parameters_file}
  end

end
