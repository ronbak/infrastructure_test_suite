require 'azure_mgmt_resources'
require_relative 'WRAzureCredentials'
require_relative 'WRAzureResourceManagement'
require_relative 'CSRELogger'
require 'pry-byebug'

class WRAzureDeployer

  def initialize(action: nil, environment: nil, client_name: nil, resource_group_location: 'WestEurope', rg_name: nil, parameters: nil, template: nil)
    log_level = 'INFO'
    log_level = ENV['CSRE_LOG_LEVEL'] unless ENV['CSRE_LOG_LEVEL'].nil?
    @csrelog = CSRELogger.new(log_level, 'STDOUT')
    @environment = wrenvironmentdata(environment)['name']
    options = {environment: @environment, client_name: client_name}
    @credentials = WRAzureCredentials.new(options).authenticate()
    @client = WRAzureResourceManagement.new(environment: @environment, client_name: client_name)
    #@client.subscription_id = wrmetadata()[@environment]['subscription_id']
    @action = action
    @resource_group_location = resource_group_location
    @rg_name = rg_name
    @template = template
    @parameters = parameters
  end

  # Main orchestration method
  def process_deployment()
    case @action
    when 'deploy'
      @csrelog.info("Deploying to resource group: #{@rg_name}")
      deployment_name = deploy()
      deploy_status(deployment_name)
    when 'delete'
      @csrelog.info("Deleting the resource group and all it's resources: #{@rg_name}")
      delete_rg()
    end
  end
      

  # Deploy the template to a resource group
  def deploy()
    # ensure the resource group is created
    @csrelog.debug("Creating or updating the resource group: #{@rg_name}")
    @client.create_resource_group(@resource_group_location, @rg_name)

    # build the deployment from a json file template from parameters
    @csrelog.debug("Creating the deployment object")
    deployment = build_deployment_object()
    @csrelog.debug(deployment)

    deployment_name = create_deployment_name()
    @csrelog.debug("Deployment name: #{deployment_name}")
    
    # put the deployment to the resource group
    @csrelog.debug("Creating a new thread for the deployment")
    t = Thread.new {
      @client.create_update_deployment(@rg_name, deployment_name, deployment)
      @csrelog.debug("Deployment accepted")
    }
    t.join
    sleep 5
    deploy_status(deployment_name)
  end

  def deploy_status(deployment_name)
    begin
      x = @client.get_deployment_status(@rg_name, deployment_name)
      while x == "Running"
        @csrelog.info("deploying status is: #{x}")
        sleep 30
        x = @client.get_deployment_status(@rg_name, deployment_name)
      end
      @csrelog.info("Deployment complete")
      @csrelog.info(x)
      if x == 'Failed'
        operations = @client.get_deployment_operations(@rg_name, deployment_name)
        operations_messages = operations.select { |operation| operation.properties.status_message.class == Hash }
        operations_messages.each do |operation|
          @csrelog.error(operation.properties.status_message['error']['code'])
          @csrelog.error(operation.properties.status_message['error']['message'])
        end
      end
    rescue => e
      @csrelog.debug("for some reason we crashed out, not sure why\n\n#{e}\n\n\n\n")
    end
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

  def delete_rg()
    @csrelog.debug(@rg_name)
    @csrelog.debug(@client.delete_resource_group(@rg_name))
  end

end
