require 'azure_mgmt_resources'
require_relative 'WRAzureCredentials'
require_relative 'WRAzureResourceManagement'
require_relative 'CSRELogger'
require_relative 'WRAzureNsgRulesMgmt'
require_relative 'WRAzureTemplateManagement'
require_relative 'WRSubnetsArrayBuilder'
require_relative 'WRAzureTemplateValidator'
require 'pry-byebug'

# Main orchestration class for building the deployment object and sending to Azure
class WRAzureDeployer

  def initialize(action: nil, config_manager: nil, environment: nil, complete_deployment: false, rules_template: nil, skip_deploy: false, output: nil, prep_templates: false, no_upload: true)
    log_level = 'INFO'
    log_level = ENV['CSRE_LOG_LEVEL'] unless ENV['CSRE_LOG_LEVEL'].nil?
    @csrelog = CSRELogger.new(log_level, 'STDOUT')
    # Boolean deployment mode switch
    @complete_deployment = complete_deployment
    @environment = wrenvironmentdata(environment)['name']
    @metadata = wrmetadata()
    @landscape = environment
    # Setup credentials object
    options = {environment: @environment}
    @credentials = WRAzureCredentials.new(options).authenticate()
    # Setup Resource Manager object
    @client = WRAzureResourceManagement.new(environment: @environment, landscape: @landscape)
    @action = action
    @config_manager = config_manager
    @rg_name = @config_manager.rg_name(@landscape)
    @template = @config_manager.template()
    @rules_template = rules_template
    @parameters = @config_manager.parameters()
    # Merges landscape specific parameters from the configuration object
    @parameters = add_environment_values()
    # Builds subnets_array if specified in the params section
    @parameters = build_subnets_array()
    # Sets location if it exists in the parameters object
    @resource_group_location = @config_manager.parameters.dig('location', 'value')
    @resource_group_location = 'WestEurope' if @resource_group_location.nil?
    # bool
    @skip_deploy = skip_deploy
    @output = output
    @no_upload = no_upload
    # bool
    @prep_templates = prep_templates
  end

  attr_reader :template
  attr_reader :parameters

  # Main orchestration method
  def process_deployment()
    case @action
    when 'deploy'
      # Upload any linked templates in provided template to Azure Storage and updatelinked URl's
      prepare_linked_templates() if @prep_templates
      @csrelog.info("Deploying to resource group: #{@rg_name}")
      # Run the dpeloyment
      deployment_name = deploy()
      # Check status of deployment
      deploy_status(deployment_name)
    when 'delete'
      @csrelog.info("Deleting the resource group and all it's resources: #{@rg_name}")
      # Deletes the entire Resource Group
      delete_rg()
    when 'output'
      # Creates everything required for a deployment and saves the output (template and paramns files) without actually deploying. 
      @csrelog.info("Building deployment object and saving to #{@output}")
      prepare_linked_templates() if @prep_templates
      deployment_name = deploy()
    when 'validate'
      files_path = File.dirname(@output)
      files = Dir["#{files_path}/*.json"]
      templates_to_test = files.select { |file| !file.include?('.parameters.') && file.split('/')[-1].split('.')[0].eql?(@output.split('/')[-1].split('.')[0])}
      parameters_file = files.select { |file| file.include?('.parameters.') && file.split('/')[-1].split('.')[0].eql?(@output.split('/')[-1].split('.')[0])}
      parameters_file = parameters_file[0] if parameters_file.count.eql?(1)
      parameters_file = parameters_file.find { |file| file.include?(@landscape) } if parameters_file.count >= 2
      results = {}
      @csrelog.debug("Testing the following templates: #{templates_to_test}\nUsing the following parameters file: #{parameters_file}\n")
      templates_to_test.each do |template|
        @csrelog.debug("\nTesting template: #{template}")
        result = WRAzureTemplateValidator.new(template: template, parameters: parameters_file, environment: @environment, rg_name: @rg_name).valid_template?
        @csrelog.debug("Result: #{result}\n")
        results[template] = result
      end
      @csrelog.fatal("One or mpore of your templates failed validation: #{results}") if results.values.include?(false)
      exit 1 if results.values.include?(false)
      @csrelog.debug("Your templates passed validation: #{results}")
      return results
    end
  end
      
  # Deploy the template to a resource group
  def deploy()
    unless @skip_deploy
      # ensure the resource group is created
      unless @action == 'output'
        @csrelog.debug("Creating or updating the resource group: #{@rg_name}") if @config_manager.tags
        @client.create_resource_group(@resource_group_location, @rg_name, @config_manager.tags) if  @config_manager.tags
        # If there are linked templates, update the access policy to allow access for the next 30 mins.
        if @prep_templates
          @csrelog.debug("Setting container access policy expiry to: #{Time.now + 30*60}")
          storer = WRAzureStorageManagement.new(environment: @environment, container: @metadata.dig(@environment, 'storage_account', 'templates_container'))
          storer.set_access_policy_expiry(@metadata.dig(@environment, 'storage_account', 'container_access_policy'), 30)
        end
      end
      # Builds the deployment object and passes to Azure API
      deployment_name = run_deployment(@template, @complete_deployment)
      # Checks the status of the deployment
      deploy_status(deployment_name) unless @action == 'output'
    end
  end

  def run_deployment(template, complete_deployment = false)
    @csrelog.debug("Creating the deployment object")
    # Builds the deployment object
    deployment = build_deployment_object(template, complete_deployment)
    @csrelog.debug(deployment)
    # Creates a unique name for this deployment to track in Azure
    deployment_name = create_deployment_name()
    @csrelog.debug("Deployment name: #{deployment_name}")
    #If an output path has been specified, save the template and params
    output_deployment_object(@output, deployment) if @output

    # Create a new thread and pass the deployment to Azure API
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

  # Retrieves deployment status from Azure, runs as long as deployment is running. 
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
            exit 1
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
    deployment.properties.parameters = @parameters
    deployment.properties.template = template
    return deployment
  end

  def add_environment_values()
    # Adds environment to params object if it exists in the template parameters required list
    @parameters['environment'] = { "value" => @landscape } if @template.dig('parameters', 'environment')
    # Merges the environment specific and default parameters from the configuration file
    @parameters = @parameters.deep_merge(@config_manager.environments[@landscape]['parameters']) if @config_manager.environments.dig(@landscape)
    @parameters
  end
  
  # builds an array of all subnets if required
  def build_subnets_array()
    WRSubnetsArrayBuilder.new(@parameters, @environment, @csrelog).parameters
  end

  # Uploads any linked templates to Azure Storage and updates master template URL and adds SAS token. 
  def prepare_linked_templates()
    @template = WRAzureTemplateManagement.new(@template, @environment, @rules_template, @parameters, @output, @no_upload, @csrelog).process_templates()
  end

  def add_rules_to_existing_template()
    # build the rules resources
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

  # Cycles through any rules in and creates them for each subnet in the subnet_array parameter
  def build_rules_template(parameters, base_template)
    WRAzureNsgRulesMgmt.new(parameters, base_template, @csrelog).process_rules
  end

  # Takes the final template and parameters objects and writes them to files
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

  def delete_rg()
    @csrelog.debug(@rg_name)
    @csrelog.debug(@client.delete_resource_group(@rg_name))
  end

end
