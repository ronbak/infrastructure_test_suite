require_relative 'global_methods'
require_relative 'CSRELogger'

class WRConfigManager
  
  def initialize(config: nil)
    log_level = 'INFO'
    @csrelog = CSRELogger.new(log_level, 'STDOUT')
    @config = parse_config(config)
  end

  def retrieve_config(config)
  end

  def parse_config(config)
    config_hash = nil
    if uri?(config)
      # uri received, pull from internets
      config_hash = JSON.parse(get_data_from_url(config).body)
    elsif config.class == Hash
      # already parsed config, send back as is
      config_hash = config
    elsif File.exist?(config)
      # file path given, read it and parse
      config_hash = JSON.parse(File.read(config))
    else
      # assume (rightly or wrongly) the config object is a json string, pasre it.
      config_hash = JSON.parse(config)
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
    @config['environments'][env]['resource_group_name']
  end


end

