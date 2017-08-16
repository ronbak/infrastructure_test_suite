require 'json'
require 'azure_mgmt_resources'
require_relative 'global_methods'
require_relative 'CSRELogger'

class WRAzureCredentials

	def initialize (options = {})
		log_level = 'INFO'
    log_level = ENV['CSRE_LOG_LEVEL'] unless ENV['CSRE_LOG_LEVEL'].nil?
		@csrelog = CSRELogger.new(log_level, 'STDOUT')
		environment = wrenvironmentdata(options[:environment])['name']
		metadata = wrmetadata()
		@client_id = options[:client_id]
		@client_id = determine_client_id(environment) if @client_id.nil?
		@tenant_id = metadata[environment]['tenant_id']
		@client_secret = get_client_secret()
	end

	def get_client_secret()
		if ENV['AZURE_CLIENT_SECRET']
			return ENV['AZURE_CLIENT_SECRET']
		elsif File.exist?("#{ENV['HOME']}/.ssh/azure_ruby_key") && File.exist?("#{ENV['HOME']}/azure_ruby_creds_#{@tenant_id}")
			@csrelog.debug("found a creds file, attempting to decrypt the info")
			return decrypt(File.read("#{ENV['HOME']}/azure_ruby_creds_#{@tenant_id}"))
		else
			@csrelog.info("No Secret Found")
			@csrelog.info("Please set the secret in the environment variable 'AZURE_CLIENT_SECRET'")
			puts 'Please paste your secret here:'
			secret = gets.chomp
			write_creds_file(secret)
			return decrypt(File.read("#{ENV['HOME']}/azure_ruby_creds_#{@tenant_id}"))
		end
	end

	def write_creds_file(creds)
		key_file = "#{ENV['HOME']}/azure_ruby_creds_#{@tenant_id}"
		x = encrypt(creds)
		json = 
		open key_file, 'w' do |io| io.write x end
	end

	def determine_client_id(environment)
		wrenvironmentdata(environment)['service_principal'].values[0]
	end

	def authenticate()
		token_provider = MsRestAzure::ApplicationTokenProvider.new(@tenant_id, @client_id, @client_secret)
		return MsRest::TokenCredentials.new(token_provider)
	end
end
