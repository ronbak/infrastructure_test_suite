require 'azure_mgmt_resources'
require_relative 'WRAzureCredentials'
require_relative 'CSRELogger'
require_relative 'WRConfigManager'
require 'pry-byebug'


# Main orchestration class for building the deployment object and sending to Azure
class WRAzureTemplateValidator

  def initialize(template: nil, parameters: nil, environment: nil, rg_name: nil)
    log_level = 'INFO'
    log_level = ENV['CSRE_LOG_LEVEL'] unless ENV['CSRE_LOG_LEVEL'].nil?
    @csrelog = CSRELogger.new(log_level, 'STDOUT')
    @environment = wrenvironmentdata(environment)['name']
    @parameters = WRConfigManager.new(config: parameters).config
    @template = WRConfigManager.new(config: template).config
    # Setup credentials object
    options = {environment: @environment}
    @credentials = WRAzureCredentials.new(options).authenticate()
    # Setup Resource Manager object
    @rg_client = Azure::ARM::Resources::ResourceManagementClient.new(@credentials)
    @rg_client.subscription_id = wrmetadata()[@environment]['subscription_id']
    @rg_name = rg_name
  end

  attr_reader :template
  attr_reader :parameters

  def valid_template?
    deployment = build_deployment_object()
    deployment_name = create_deployment_name()
    result = @rg_client.deployments.validate(@rg_name, deployment_name, deployment)
    if result.properties
      return true if result.properties.provisioning_state.eql?('Succeeded')
    else
      begin
        @csrelog.error("Your template failed validation: #{result.error.code}")
      rescue
        @csrelog.error("Your template failed validation: #{result}")
      end
      return false
    end
  end


  def build_deployment_object()
    deployment = Azure::ARM::Resources::Models::Deployment.new
    deployment.properties = Azure::ARM::Resources::Models::DeploymentProperties.new
    deployment.properties.mode = Azure::ARM::Resources::Models::DeploymentMode::Complete
    deployment.properties.parameters = @parameters['parameters']
    deployment.properties.template = @template
    return deployment
  end
  
end

