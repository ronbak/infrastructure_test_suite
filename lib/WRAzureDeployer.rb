require 'azure_mgmt_resources'
require_relative 'WRAzureCredentials'
require_relative 'WRAzureResourceManagement'
require_relative 'CSRELogger'

class WRAzureDeployer

  def initialize(environment: nil, client_name: nil, resource_group_location: 'WestEurope', rg_name: nil, parameters: nil, template: nil)
    log_level = 'INFO'
    log_level = ENV['CSRE_LOG_LEVEL'] unless ENV['CSRE_LOG_LEVEL'].nil?   
    @csrelog = CSRELogger.new(log_level, 'STDOUT')
    @environment = wrenvironmentdata(environment)['name']
    options = {environment: @environment, client_name: client_name}
    @credentials = WRAzureCredentials.new(options).authenticate()
    @client = WRAzureResourceManagement.new(environment: @environment, client_name: client_name)
    #@client.subscription_id = wrmetadata()[@environment]['subscription_id']
    @resource_group_location = resource_group_location
    @rg_name = rg_name
    @template = template
    @parameters = parameters
  end

  # Deploy the template to a resource group
  def deploy()
    # ensure the resource group is created
    @client.create_resource_group(@resource_group_location, @rg_name)

    # build the deployment from a json file template from parameters
    deployment = build_deployment_object()

    deployment_name = create_deployment_name()
    
    # put the deployment to the resource group TODOOOOOOO
    Thread.new {
      @client.create_update_deployment(@rg_name, deployment_name, deployment)
    }
    sleep 5
    deploy_status(deployment_name)
  end

  def deploy_status(deployment_name)
    x = @client.get_deployment_status(@rg_name, deployment_name)
    while x == "Running"
      puts "deploying status is: #{x}"
      sleep 30
      x = @client.get_deployment_status(@rg_name, deployment_name)
    end
    puts "Deployment complete"
    puts x
  end

  def build_deployment_object() # TODO
    deployment = Azure::ARM::Resources::Models::Deployment.new
    deployment.properties = Azure::ARM::Resources::Models::DeploymentProperties.new
    deployment.properties.mode = Azure::ARM::Resources::Models::DeploymentMode::Incremental
    deployment.properties.parameters = @parameters
    deployment.properties.template = @template
    return deployment
  end

  def get_params(string) 
    if uri?(string)
      obj = get_data_from_url(string).body
    else
      obj = File.read(string)
    end
    return JSON.parse(obj)["parameters"]
  end

  def get_json_object(string)
    if uri?(string)
      obj = get_data_from_url(string).body
    else
      obj = File.read(string)
    end
    return JSON.parse(obj)
  end

  def delete()
    @client.delete_resource_group(@rg_name)
  end

end
