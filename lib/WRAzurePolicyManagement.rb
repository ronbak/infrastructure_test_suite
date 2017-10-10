
require_relative 'global_methods'
require_relative 'CSRELogger'
require_relative 'WRAzureCredentials'
require_relative 'WRConfigManager'
require 'azure_mgmt_policy'
require 'pry-byebug'

class WRAzurePolicyManagement

	def initialize(environment: nil, landscape: nil)
		log_level = 'INFO'
    log_level = ENV['CSRE_LOG_LEVEL'] unless ENV['CSRE_LOG_LEVEL'].nil?
		@csrelog = CSRELogger.new(log_level, 'STDOUT')
    @environment = wrenvironmentdata(environment)['name']
    @landscape = landscape
		options = {environment: @environment}
		@credentials = WRAzureCredentials.new(options).authenticate()
		@pl_client = Azure::ARM::Policy::PolicyClient.new(@credentials)
		@pl_client.subscription_id = wrmetadata()[@environment]['subscription_id']
	end

  def build_policy_definition(policy_data)
    policy_hash = WRConfigManager.new(config: policy_data).config
    id_to_use = policy_exist?(policy_hash)
    id_to_use = SecureRandom.uuid unless id_to_use
    definition = Azure::ARM::Policy::Models::PolicyDefinition.new()
    definition.description = policy_hash['properties']['description']
    definition.display_name = policy_hash['properties']['displayName']
    definition.id = "/providers/Microsoft.Authorization/policyDefinitions/#{id_to_use}"
    definition.name = id_to_use
    definition.parameters = {}
    definition.policy_rule = policy_hash['properties']['policyRule']
    definition.policy_type = 'Custom'
    return {id_to_use => definition}
  end

  def build_policy_set_definition(policy_data)
    policy_set_hash = WRConfigManager.new(config: policy_data).config
    id_to_use = policy_set_exist?(policy_set_hash)
    id_to_use = SecureRandom.uuid unless id_to_use
    definition_set = Azure::ARM::Policy::Models::PolicySetDefinition.new()
    definition_set.description = policy_set_hash['properties']['description']
    definition_set.display_name = policy_set_hash['properties']['displayName']
    definition_set.id = "/providers/Microsoft.Authorization/policydefinitionsets/#{id_to_use}"
    definition_set.name = id_to_use
    definition_set.parameters = {}
    definition_set.policy_definitions = create_policy_set_definitions(policy_set_hash)
    definition_set.policy_type = 'Custom'
    return {id_to_use => definition_set}
  end

  def create_policy_set_definitions(policy_set_hash)
    policy_definitions = []
    policy_set_hash['properties']['policyDefinitions'].each do |definition_id|
      definition = Azure::ARM::Policy::Models::PolicyDefinitionReference.new()
      definition.policy_definition_id = definition_id['policyDefinitionId']
      policy_definitions << definition
    end
    return policy_definitions
  end

  def create_policy(policy_data)
    definition = build_policy_definition(policy_data)
    begin
      @pl_client.policy_definitions.create_or_update(definition.keys[0], definition.values[0])
      return definition.values[0].id
    rescue Exception => e
      return e
    end
  end
	
  def assign_policy(policy_data, scope = nil)
    policy_hash = WRConfigManager.new(config: policy_data).config
    policy_name = policy_exist?(policy_hash)
    policy = @pl_client.policy_definitions.get(policy_name)
    pol_assignment = set_policy_assignment(policy, scope)
    return pol_assignment
  end

  def create_policy_set(policy_data)
    definition_set = build_policy_set_definition(policy_data)
    policy_set = @pl_client.policy_set_definitions.create_or_update(definition_set.keys[0], definition_set.values[0])
    set_policy_assignment(policy_set)
  end

  def policy_exist?(policy_hash)
    all_policies = @pl_client.policy_definitions.list()
    policies = all_policies.select { |policy| policy.display_name == policy_hash['properties']['displayName'] && policy.policy_type == 'Custom'}
    return false if policies.empty?
    return policies.first.name
  end

  def policy_set_exist?(policy_hash)
    all_policies = @pl_client.policy_set_definitions.list()
    policies = all_policies.select { |policy| policy.display_name == policy_hash['properties']['displayName'] && policy.policy_type == 'Custom'}
    return false if policies.empty?
    return policies.first.name
  end

  def assignment_exist?(assignment_name)
    all_assignments = @pl_client.policy_assignments.list()
    assignments = all_assignments.select { |assignment| assignment.display_name == assignment_name}
    return false if assignments.empty?
    return assignments.first.name
  end

  def find_assignment(assignment_display_name)
    all_assignments = @pl_client.policy_assignments.list()
    assignments = all_assignments.select { |assignment| assignment.display_name == assignment_display_name}
    return false if assignments.empty?
    return assignments.first
  end

  def set_policy_assignment(policy, scope = nil)
    assignment = build_policy_assignment(policy)
    scope = policy.id.split('providers')[0][0..-2] unless scope
    pl_assignment = @pl_client.policy_assignments.create(scope, assignment.name, assignment)
    return pl_assignment
  end

  def build_policy_assignment(policy)
    assignment_display_name = "#{policy.display_name} - #{@environment}"
    assignment = Azure::ARM::Policy::Models::PolicyAssignment.new()
    assignment.display_name = assignment_display_name
    id_to_use = assignment_exist?(assignment_display_name)
    id_to_use = SecureRandom.uuid unless id_to_use
    assignment.id = id_to_use
    assignment.name = assignment_display_name.gsub('-', '').gsub('  ', ' ').gsub(' ', '-')
    assignment.parameters = {}
    assignment.policy_definition_id = policy.id
    assignment.sku = Azure::ARM::Policy::Models::PolicySku.new()
    assignment.sku.name = 'A0'
    assignment.sku.tier = 'Free'
    assignment.type = 'Microsoft.Authorization/policyAssignments'
    return assignment
  end

  def delete_policy_assignment(policy_data)
    policy_hash = WRConfigManager.new(config: policy_data).config
    assignment_display_name = policy_hash['properties']['displayName'] + " - #{@environment}"
    assignment = find_assignment(assignment_display_name)
    @pl_client.policy_assignments.delete_by_id(assignment.id) if assignment
  end
end
