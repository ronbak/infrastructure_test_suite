require 'azure_mgmt_resources'
require_relative 'WRAzureCredentials'
require_relative 'WRAzureResourceManagement'
require_relative 'CSRELogger'
require_relative 'WRAzureNsgRulesMgmt'
require 'pry-byebug'

class WRAzureDeployer

  def initialize(action: nil, environment: nil, client_name: nil, resource_group_location: 'WestEurope', rg_name: nil, parameters: nil, template: nil, complete_deployment: false, rules_template: nil, skip_deploy: false, output: nil)
    log_level = 'INFO'
    log_level = ENV['CSRE_LOG_LEVEL'] unless ENV['CSRE_LOG_LEVEL'].nil?
    @csrelog = CSRELogger.new(log_level, 'STDOUT')
    @complete_deployment = complete_deployment
    @environment = wrenvironmentdata(environment)['name']
    options = {environment: @environment, client_name: client_name}
    @credentials = WRAzureCredentials.new(options).authenticate()
    @client = WRAzureResourceManagement.new(environment: @environment, client_name: client_name)
    #@client.subscription_id = wrmetadata()[@environment]['subscription_id']
    @action = action
    @resource_group_location = resource_group_location
    @rg_name = rg_name
    @template = template
    @rules_template = rules_template
    @parameters = parameters
    @skip_deploy = skip_deploy
    @output = output
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
    when 'output'
      @csrelog.info("Building deployment object and saving to #{@output}")
      deployment_name = deploy()
    end
  end
      
  # Deploy the template to a resource group
  def deploy()
    unless @skip_deploy
      # ensure the resource group is created
      @csrelog.debug("Creating or updating the resource group: #{@rg_name}") unless @action == 'output'
      @client.create_resource_group(@resource_group_location, @rg_name) unless @action == 'output'
      if @rules_template
        add_rules_to_exisitng_template()
      end
      deployment_name = run_deployment(@template, @complete_deployment)
      deploy_status(deployment_name) unless @action == 'output'
    end
  end

  def add_rules_to_exisitng_template()
    #binding.pry
    # build the rules resourecs
    rules_expanded_resources = build_rules_template(@parameters, @rules_template)
    # add dependsOn to each rule resource
    base_resources = []
    @template['resources'].each do |resource|
      base_resources << resource['name']
    end
    rules_expanded_resources.each do |rules_resource|
      rules_resource['dependsOn'] = base_resources
    end
    # add rules resources to existing template
    @template['resources'] += rules_expanded_resources
  end

  def run_deployment(template, complete_deployment = false)
    @csrelog.debug("Creating the deployment object")
    deployment = build_deployment_object(template, complete_deployment)
    @csrelog.debug(deployment)

    deployment_name = create_deployment_name()
    @csrelog.debug("Deployment name: #{deployment_name}")
    output_deployment_object(@output, deployment) if @output

    @csrelog.debug("Creating a new thread for the deployment")
    unless @action == 'output'
      t1 = Thread.new {
        begin 
          @client.create_update_deployment(@rg_name, deployment_name, deployment)
          @csrelog.info("Deployment accepted")
        rescue => e
          @csrelog.error("we hit an issue deploying your template.....")
          @csrelog.error(e.error_message)
          @csrelog.error("We will now exit, please try harder next time! :) ")
          exit 1
        end
      }
    end
    sleep 5
    return deployment_name
  end

  def build_rules_template(parameters, base_template)
    WRAzureNsgRulesMgmt.new(parameters, base_template, @csrelog).process_rules
  end

  def deploy_status(deployment_name)
      unless deployment_name.nil?
      begin
        x = @client.get_deployment_status(@rg_name, deployment_name)
        while x == "Running"
          @csrelog.info("deploying status is: #{x}")
          sleep 15
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
  end

  def build_deployment_object(template, complete_deployment = false)
    @csrelog.info('We\'re running in Incremental mode...this might be forced if doing a rules deployment') unless complete_deployment
    @csrelog.debug('We\'re running in Complete mode.') if complete_deployment
    deployment = Azure::ARM::Resources::Models::Deployment.new
    deployment.properties = Azure::ARM::Resources::Models::DeploymentProperties.new
    deployment.properties.mode = Azure::ARM::Resources::Models::DeploymentMode::Incremental
    deployment.properties.mode = Azure::ARM::Resources::Models::DeploymentMode::Complete if complete_deployment
    @csrelog.debug(deployment.properties.mode)
    @parameters = add_environment_value()
    deployment.properties.parameters = @parameters
    deployment.properties.template = template
    return deployment
  end

  def add_environment_value()
    @parameters['environment'] = { "value" => @environment } if @template.dig('parameters', 'environment')
    @parameters
  end

  def output_deployment_object(file_path, deployment_object)
    output_params_hash = {
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0"}
    output_params_hash[:parameters] = deployment_object.properties.parameters
    params_file = File.dirname(file_path) + '/' + file_path.split('/')[-1].split('.')[0] + '.parameters.json'
    write_hash_to_disk(output_params_hash, params_file)
    output_hash = deployment_object.properties.template
    file_path = "#{file_path}.json" unless file_path[-5..-1] == '.json'
    write_hash_to_disk(output_hash, file_path)
  end

  def write_hash_to_disk(hash, file_path)
    File.open(file_path, 'w') do |file|
      file.write JSON.pretty_generate(hash)
    end
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
