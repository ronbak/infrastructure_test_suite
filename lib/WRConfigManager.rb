require_relative 'global_methods'
require_relative 'CSRELogger'
require 'pry-byebug'

class WRConfigManager
  
  def initialize(config: nil)
    # log_level = 'INFO'
    # log_level = ENV['CSRE_LOG_LEVEL'] unless ENV['CSRE_LOG_LEVEL'].nil?
    @csrelog = CSRELogger.new()
    @config = parse_config(config)
  end

  def retrieve_config(config)
  end

  def parse_config(config)
    config_hash = nil
    if uri?(config)
      # uri received, pull from internets
      @csrelog.debug("object is a uri: #{config}")
      # Try to get the data from Git Anonymously
      if config[0..29] == 'https://source.worldremit.com/'
        @csrelog.debug('Your url is in Worldremit GitLab. Attempting to retrieve token and authenticate')
        access_token = WRAzureCredentials.new().get_gitlab_access_token
        raw_data = retrieve_from_internet_anonymous("#{config}?private_token=#{access_token}")
      elsif config[0..44] == 'https://raw.githubusercontent.com/Worldremit/'
        @csrelog.debug('Your url is in WorldRemit Github, attempting to authenticate first')
        config = convert_git_raw_to_api(config)
        # Get Git Access Token
        access_token = WRAzureCredentials.new().get_git_access_token
        raw_data = retrieve_from_github_api(config, access_token)
      else
        @csrelog.debug("Attempting to download anonymously")
        raw_data = retrieve_from_internet_anonymous(config)  
      end      
      config_hash = JSON.parse(raw_data) if raw_data
    elsif config.class == Hash
      # already parsed config, send back as is
      @csrelog.debug("object is a hash: #{config}")
      config_hash = config
    elsif File.exist?(config)
      # file path given, read it and parse
      @csrelog.debug("object exists as a file: #{config}")
      config_hash = JSON.parse(File.read(config))
    elsif valid_json?(config)
      # the config object is a json string, parse it.
      @csrelog.debug("object is a valid json string, parsing now")
      config_hash = JSON.parse(config)
    else
      @csdrelog.fatal("We couldn't determine what your cponfig file is, please verify the path / string
        #{config}")
      exit 1
    end
    return config_hash
  end

  def parameters()
    @config['parameters']
  end

  def environments()
    @config['environments']
  end

  def template()
    parse_config(@config['environments']['global']['arm_template'])
  end

  def config()
    @config
  end

  def client_name()
    @config['environments']['global']['client_name']
  end

  def rg_name(env)
    @config['environments'][env.to_s]['resource_group_name']
  end


end

