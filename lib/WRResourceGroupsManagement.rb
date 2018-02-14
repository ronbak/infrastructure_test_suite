require_relative 'global_methods'
require_relative 'CSRELogger'
require_relative 'WRAzureCredentials'
require_relative 'WRConfigManager'
require 'azure_mgmt_authorization'
require 'azure_mgmt_resources'
require 'pry-byebug'

class WRResourceGroupsManagement

  def initialize(config: nil, location: 'WestEurope', environment: nil)
    log_level = 'INFO'
    log_level = ENV['CSRE_LOG_LEVEL'] unless ENV['CSRE_LOG_LEVEL'].nil?
    @csrelog = CSRELogger.new(log_level, 'STDOUT')
    @config = WRConfigManager.new(config: config).config
    @location = if @config['tags']['Location']
                  @config['tags']['Location']
                else
                  location
                end
    @name = @config['name']
    @environment = wrenvironmentdata(environment.to_s)['name']
    @landscape = environment.to_s
    @config['universal'] = true unless @config['universal'].eql?(false)
  end

  def process_groups()
  # Create resource groups in all landscapes
    @csrelog.info('Beginning creation of user groups')
    create_rg_objects()
    if (@environment.eql?('nonprd') && @config['universal']) || @landscape.eql?('dev')
   # assign user group to Dev resource group RBAC role etc
      au_client = create_azure_au_client(@environment) if au_client.nil?
      au_client = create_azure_au_client(@environment) unless au_client.subscription_id == wrenvironmentdata(@environment)['subscription_id']
      begin
        assign_usergroup_rg(au_client, @config['access_group_id'], "#{@name}-rg-dev-wr", 'cust-Contributor-no-pip-sa-rg')
        # Add the octopus-dev-app SPN to the group
        assign_usergroup_rg(au_client, wrmetadata().dig('global', 'service_principals', 'octopus-dev-app-wr'), "#{@name}-rg-dev-wr", 'cust-Contributor-no-pip-sa-rg')
      rescue => e
        @csrelog.error(e)
      end
    end
  end

  def assign_usergroup_rg(client, usergroup_id, rg_name, role_name)
    #client = create_azure_au_client('nonprod')
    # rg_name = "#{@name}-rg-dev-wr"
    scope = "/subscriptions/#{client.subscription_id}/resourceGroups/#{rg_name}"
    role_definition_id = "/subscriptions/#{client.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/#{wrmetadata().dig('global', 'rbac_roles', role_name)}"
    unless find_assignment(client, scope, role_definition_id, usergroup_id)
      role_assignment_name = SecureRandom.uuid
      parameters = Azure::ARM::Authorization::Models::RoleAssignmentCreateParameters.new()
      parameters.properties = Azure::ARM::Authorization::Models::RoleAssignmentProperties.new()
      parameters.properties.role_definition_id = "/subscriptions/#{client.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/#{wrmetadata().dig('global', 'rbac_roles', role_name)}"
      parameters.properties.principal_id = usergroup_id
      client.role_assignments.create(scope, role_assignment_name, parameters)
    else
      @csrelog.warn("The assignment for:-
        Group ID: #{usergroup_id}
        RBAC Role ID: #{wrmetadata().dig('global', 'rbac_roles', role_name)}
        ResourceGroup (Scope): #{rg_name}
        Is already present.....skipping this RBAC role assignment")
    end
  end

  def find_assignment(client, scope, role_definition_id, usergroup_id)
    assignments = client.role_assignments.list
    obj = assignments.find do |assignment| 
      assignment.properties.principal_id == usergroup_id && assignment.properties.role_definition_id == role_definition_id && assignment.properties.scope == scope
    end
    return obj
  end

  def list_landscapes(environment = 'nonprd')
    return wrmetadata['global']['landscapes'][wrenvironmentdata(environment.to_s).dig('name')] if @config['universal']
    [environment]
  end

  def create_rgs(subscription = 'nonprd')
    list_landscapes(subscription).each do |landscape|
      tags_hash = create_tags_hash(Marshal::load(Marshal.dump(@config['tags'])), landscape)
      rm_client = create_azure_rm_client(@environment) if rm_client.nil?
      rm_client = create_azure_rm_client(@environment) unless rm_client.subscription_id == wrenvironmentdata(@environment)['subscription_id']
      @csrelog.info("Creating resource group: #{tags_hash['name']}")
      create_rg(rm_client, @location, tags_hash['name'], tags_hash)
      au_client = create_azure_au_client(@environment) if au_client.nil?
      au_client = create_azure_au_client(@environment) unless au_client.subscription_id == wrenvironmentdata(@environment)['subscription_id']
      @csrelog.info("Assigning permissions for resource group: #{tags_hash['name']}")
      assign_usergroup_rg(au_client, @config['access_group_id'], tags_hash['name'], 'Reader')
      assign_usergroup_rg(au_client, wrmetadata().dig('global', 'service_principals', 'octopus-dev-app-wr'), tags_hash['name'], 'cust-Contributor-no-pip-sa-rg') unless @environment.eql?('core')
    end
  end

  def create_rg_objects()
    create_rgs(@landscape)
  end

  def create_azure_rm_client(subscription)
    environment = wrenvironmentdata(subscription)['name']
    options = {environment: environment}
    credentials = WRAzureCredentials.new(options).authenticate()
    rm_client = Azure::ARM::Resources::ResourceManagementClient.new(credentials)
    rm_client.subscription_id = wrmetadata()[environment]['subscription_id']
    return rm_client
  end

  def create_azure_au_client(subscription)
    environment = wrenvironmentdata(subscription)['name']
    options = {environment: environment}
    credentials = WRAzureCredentials.new(options).authenticate()
    auth_client = Azure::ARM::Authorization::AuthorizationManagementClient.new(credentials)
    auth_client.subscription_id = wrmetadata()[environment]['subscription_id']    
    return auth_client
  end

  def create_tags_hash(tags, environment)
    case @location.downcase
    when 'northeurope'
      location_tag = 'eurn'
    else
      location_tag = 'eurw'
    end
    tags['name'] = "#{@name}-rg-#{environment}-wr"
    tags['environment'] = environment
    tags['location'] = @location
    tags['RunModel'] = 'm-f' if environment == 'dev'
    @csrelog.debug('Defaulting \'RunModel\' to \'m-f\' for Dev environment') if environment.eql?('dev')
    tags['RunModel'] = '247' if environment == 'prd'
    @csrelog.debug('Defaulting \'RunModel\' to \'247\' for Prd environment') if environment.eql?('prd')
    tags['RunModel'] = @config['tags']['RunModel'] unless environment.eql?('prd') || environment.eql?('dev')
    return tags
  end

  def create_rg(rm_client, location, rg_name, tags_hash)
    params = Azure::ARM::Resources::Models::ResourceGroup.new().tap do |rg|
      rg.location = location
      rg.tags = tags_hash
    end
    rm_client.resource_groups.create_or_update(rg_name, params).properties.provisioning_state
  end
end