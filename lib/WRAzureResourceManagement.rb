require_relative 'global_methods'
require_relative 'CSRELogger'
require_relative 'WRAzureCredentials'

class WRAzureResourceManagement

	def initialize(environment: nil, client_name: nil)
		log_level = 'INFO'
    log_level = ENV['CSRE_LOG_LEVEL'] unless ENV['CSRE_LOG_LEVEL'].nil?
		@csrelog = CSRELogger.new(log_level, 'STDOUT')
		options = {environment: environment, client_name: client_name}
		@credentials = WRAzureCredentials.new(options).authenticate()
		@environment = environment
		@rg_client = Azure::ARM::Resources::ResourceManagementClient.new(@credentials)
		@rg_client.subscription_id = wrmetadata()[@environment]['subscription_id']
	end

	def create_resource_group(location, rg_name)
	  params = Azure::ARM::Resources::Models::ResourceGroup.new().tap do |rg|
      rg.location = location
    end
    @rg_client.resource_groups.create_or_update(rg_name, params).properties.provisioning_state
  end

	def list_resource_groups()
		response = @rg_client.resource_groups.list
		resources_array = []
		response.each do |rg|
			resources_array << rg.name
		end
		return resources_array
	end

	def list_all_resources()
		@rg_client.resources.list
	end

	def check_naming_convention(resources, resource_type, regex)
		incorrect_objects = []
		list = resources.select { |resource| resource.type == resource_type }
		list.each do |resource|
			unless (resource.name.match(/#{regex}/))
				incorrect_objects << resource.name
			end
		end
		return incorrect_objects
	end

	def check_all_naming_convention()
		bad_names = []
		objects = list_all_resources()
		resource_types = []
		objects.each do |resource|
			resource_types << resource.type
		end
		resource_types = resource_types.uniq
		resource_types.each do |resource_type|
			pattern = wrmetadata_regex(resource_type)
			pattern = wrmetadata_regex('default_pattern') if pattern.nil?
			incorrect_objects = { resource_type => check_naming_convention(objects, resource_type, pattern)} unless pattern.nil?
			bad_names << incorrect_objects
		end
		return bad_names
	end

end
 
# ENV['AZURE_CLIENT_SECRET'] = 'F9Ci6PVKnrHYoMJ2QN+iP1k/REWVuKV8N4idWhnkcGA='
# x = WRAzureResourceManagement.new(environment: 'dev', client_id: 'f03b94d9-6086-4570-808b-45b4a81af751')

client_name = 'armTemplateAutomation'
environment = 'dev'