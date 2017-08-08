require_relative 'global_methods'

class WRAzureResourceManagement

	def initialize(environment: nil, client_name: nil)
		@csrelog = CSRELogger.new(log_level, 'STDOUT')
		options = {environment: environment, client_name: client_name}
		@credentials = WRAzureCredentials.new(options).authenticate()
		@environment = environment
	end

	def list_resource_groups()
		rg_client = Azure::ARM::Resources::ResourceManagementClient.new(@credentials)
		rg_client.subscription_id = wrmetadata()[@environment]['subscription_id']
		response = rg_client.resource_groups.list
		resources_array = []
		response.each do |rg|
			resources_array << rg.name
		end
		return resources_array
	end
end

# ENV['AZURE_CLIENT_SECRET'] = 'F9Ci6PVKnrHYoMJ2QN+iP1k/REWVuKV8N4idWhnkcGA='
# x = WRAzureResourceManagement.new(environment: 'dev', client_id: 'f03b94d9-6086-4570-808b-45b4a81af751')
