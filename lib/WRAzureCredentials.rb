require 'json'
require 'azure_mgmt_resources'
require_relative 'global_methods'
require_relative 'CSRELogger'

class WRAzureCredentials

	def initialize (options = {})
		@csrelog = CSRELogger.new(log_level, 'STDOUT')
		environment = options[:environment]
		metadata = wrmetadata()
		@client_id = options[:client_id]
		@client_id = determine_client_id(options[:client_name]) if @client_id.nil?
		@tenant_id = metadata['global']['tenant_id']
		@client_secret = get_client_secret()
	end

	def get_client_secret()
		if ENV['AZURE_CLIENT_SECRET']
			return ENV['AZURE_CLIENT_SECRET']
		else
			@csrelog.info("No Secret Found\nPlease set the secret in the environment variable 'AZURE_CLIENT_SECRET'")
			#exit 1
		end
	end

	def determine_client_id(client_name)
		wrmetadata()['global']['service_principals'][client_name]
	end

	def authenticate()
		token_provider = MsRestAzure::ApplicationTokenProvider.new(@tenant_id, @client_id, @client_secret)
		return MsRest::TokenCredentials.new(token_provider)
	end
end
