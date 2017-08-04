require 'json'
require 'azure_mgmt_resources'
require_relative 'global_methods'

class WRAzureCredentials

	def initialize (options = {})
		environment = options[:environment]
		metadata = wrmetadata()
		@client_id = options[:client_id]
		@tenant_id = metadata['global']['tenant_id']
		@client_secret = get_client_secret()
	end

	def get_client_secret()
		if ENV['AZURE_CLIENT_SECRET']
			return ENV['AZURE_CLIENT_SECRET']
		else
			puts "No Secret Found\nPlease set the secret in the environment variable 'AZURE_CLIENT_SECRET'"
			#exit 1
		end
	end

	def authenticate()
		token_provider = MsRestAzure::ApplicationTokenProvider.new(@tenant_id, @client_id, @client_secret)
		return MsRest::TokenCredentials.new(token_provider)
	end
end
