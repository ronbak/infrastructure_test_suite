require 'azure_mgmt_resources'
require_relative 'WRAzureCredentails'
require_relative 'CSRELogger'

class WRAzureDeployer

  def initialize(environment: nil, client_name: nil, resource_group_location: 'WestEurope', rg_name: nil)
    log_level = 'INFO'
    log_level = ENV['CSRE_LOG_LEVEL'] unless ENV['CSRE_LOG_LEVEL'].nil?   
    @csrelog = CSRELogger.new(log_level, 'STDOUT')
    options = {environment: environment, client_name: client_name}
    @credentials = WRAzureCredentials.new(options).authenticate()
    @environment = environment
    @client = WRAzureResourceManagement.new(environment: environment, client_name: client_name)
    @client.subscription_id = wrmetadata()[@environment]['subscription_id']
    @resource_group_location = resource_group_location
    @rg_name = rg_name

  end

  # Deploy the template to a resource group
  def deploy
    # ensure the resource group is created
    @client.create_resource_group(@resource_group_location, @rg_name)


    # build the deployment from a json file template from parameters
    deployment = build_deployment_object()
    
    # put the deployment to the resource group TODOOOOOOO
    @client.deployments.create_or_update(@resource_group, 'azure-sample', deployment)
  end

  def build_deployment_object() # TODO
    deployment = Azure::ARM::Resources::Models::Deployment.new
    deployment.properties = Azure::ARM::Resources::Models::DeploymentProperties.new
    deployment.properties.mode = Azure::ARM::Resources::Models::DeploymentMode::Incremental
    deployment.properties.parameters = get_params()
    deployment.properties.template = get_template()
  end

  def get_params() # TODO
    deploy_params = File.read(File.expand_path(File.join(__dir__, 'parameters.json')))
    return JSON.parse(deploy_params)["parameters"]
  end

  def get_template() # TODO
    template = File.read(File.expand_path(File.join(__dir__, 'template.json')))
    return JSON.parse(template)
  end
end
