require 'json'
require 'azure_mgmt_resources'
require_relative 'global_methods'
require_relative 'CSRELogger'

# Manages Azure credentials
class WRAzureCredentials

	def initialize (options = {})
		log_level = 'INFO'
    log_level = ENV['CSRE_LOG_LEVEL'] unless ENV['CSRE_LOG_LEVEL'].nil?
		@csrelog = CSRELogger.new(log_level, 'STDOUT')
		environment = 'dev'
		environment = wrenvironmentdata(options[:environment])['name'] unless options[:environment].nil?
		metadata = wrmetadata()
		@client_id = options[:client_id]
		@client_id = determine_client_id(environment) if @client_id.nil?
		@tenant_id = wrenvironmentdata(environment)['tenant_id']
		@azure_creds_file = "#{ENV['HOME']}/azure_ruby_creds_#{@tenant_id}"
		@github_pac_file = "#{ENV['HOME']}/git_ruby_pac"
		@gitlab_token_file = "#{ENV['HOME']}/gitlab_ruby_token"
		@storage_account_key = "#{ENV['HOME']}/azure_ruby_storage_key_#{environment}"
		#@client_secret = get_client_secret()
	end


	# Retrieves secret
	def retrieve_secret(env_var, encryption_key, encrypted_file)
  	# Use ENV Var if it exists
		if ENV[env_var]
			return ENV[env_var]
		# Use encrypted creds file 
		elsif File.exist?(encryption_key) && File.exist?(encrypted_file)
			@csrelog.debug("found a creds file #{encrypted_file}, attempting to decrypt the info")
			return decrypt(File.read(encrypted_file))
		# Prompt user for secret and store locally encrypted
		else
			@csrelog.info("No Secret Found")
			@csrelog.info("Please set the secret in the environment variable #{env_var}, or paste below")
			puts 'Please paste your secret here:'
			secret = gets.chomp
			write_creds_file(secret, encrypted_file)
			return decrypt(File.read(encrypted_file))
		end
	end

	# Retrieves secret for Azure
	def get_client_secret(env_var_secret = 'AZURE_CLIENT_SECRET')
		return retrieve_secret(env_var_secret, "#{ENV['HOME']}/.ssh/azure_ruby_key", @azure_creds_file)
	end

  # Retrieves secret for Git Access token (PAC)
  def get_git_access_token(env_var_secret = 'GIT_ACCESS_TOKEN')
  	retrieve_secret(env_var_secret, "#{ENV['HOME']}/.ssh/azure_ruby_key", @github_pac_file)
  end
  
  # Retrieves secret for GitLab access token
  def get_gitlab_access_token(env_var_secret = 'GITLAB_ACCESS_TOKEN')
  	retrieve_secret(env_var_secret, "#{ENV['HOME']}/.ssh/azure_ruby_key", @gitlab_token_file)
  end

  # Retrieves storage account key
  def get_storage_account_key(env_var_secret = 'AZURE_STORAGE_ACCOUNT_KEY')
  	retrieve_secret(env_var_secret, "#{ENV['HOME']}/.ssh/azure_ruby_key", @storage_account_key)
  end

  # Writes secret to an encrypted file
	def write_creds_file(creds, key_file)
		# Encrypt the secret first
		x = encrypt(creds)
		json = 
		open key_file, 'w' do |io| io.write x end
	end

	# Get client id for the serviec you're using to authenticate to Azure with
	def determine_client_id(environment)
		wrenvironmentdata(environment)['service_principal'].values[0]
	end

	# return the creds object
	def authenticate()
		token_provider = MsRestAzure::ApplicationTokenProvider.new(@tenant_id, @client_id, get_client_secret())
		return MsRest::TokenCredentials.new(token_provider)
	end
end
