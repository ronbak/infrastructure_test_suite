require 'json'
require 'azure_mgmt_resources'
require_relative 'global_methods'
require_relative 'CSRELogger'

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
		@tenant_id = metadata[environment]['tenant_id']
		@azure_creds_file = "#{ENV['HOME']}/azure_ruby_creds_#{@tenant_id}"
		@github_pac_file = "#{ENV['HOME']}/git_ruby_pac"
		@gitlab_token_file = "#{ENV['HOME']}/gitlab_ruby_token"
		@client_secret = get_client_secret()
	end

	def get_client_secret()
		if ENV['AZURE_CLIENT_SECRET']
			return ENV['AZURE_CLIENT_SECRET']
		elsif File.exist?("#{ENV['HOME']}/.ssh/azure_ruby_key") && File.exist?(@azure_creds_file)
			@csrelog.debug("found a creds file, attempting to decrypt the info")
			return decrypt(File.read(@azure_creds_file))
		else
			@csrelog.info("No Secret Found")
			@csrelog.info("Please set the secret in the environment variable 'AZURE_CLIENT_SECRET'")
			puts 'Please paste your secret here:'
			secret = gets.chomp
			write_creds_file(secret, @azure_creds_file)
			return decrypt(File.read(@azure_creds_file))
		end
	end

  def get_git_access_token()
  	if ENV['GIT_ACCESS_TOKEN']
			return ENV['GIT_ACCESS_TOKEN']
		elsif File.exist?("#{ENV['HOME']}/.ssh/azure_ruby_key") && File.exist?(@github_pac_file )
			@csrelog.debug("found a creds file, attempting to decrypt the info")
			return decrypt(File.read(@github_pac_file))
		else
			@csrelog.info("No Git PAC found")
			@csrelog.info("Please set the Git PAC in the environment variable 'GIT_ACCESS_TOKEN' or add below")
			puts 'Please paste your secret here:'
			secret = gets.chomp
			write_creds_file(secret, @github_pac_file)
			return decrypt(File.read(@github_pac_file))
		end
  end

  def get_gitlab_access_token()
  	if ENV['GITLAB_ACCESS_TOKEN']
			return ENV['GITLAB_ACCESS_TOKEN']
		elsif File.exist?("#{ENV['HOME']}/.ssh/azure_ruby_key") && File.exist?(@gitlab_token_file )
			@csrelog.debug("found a creds file, attempting to decrypt the info")
			return decrypt(File.read(@gitlab_token_file))
		else
			@csrelog.info("No Gitlab token found")
			@csrelog.info("Please set the Gitlab token in the environment variable 'GITLAB_ACCESS_TOKEN' or add below")
			puts 'Please paste your secret here:'
			secret = gets.chomp
			write_creds_file(secret, @gitlab_token_file)
			return decrypt(File.read(@gitlab_token_file))
		end
  end

	def write_creds_file(creds, key_file)
		#key_file = "#{ENV['HOME']}/azure_ruby_creds_#{@tenant_id}"
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
