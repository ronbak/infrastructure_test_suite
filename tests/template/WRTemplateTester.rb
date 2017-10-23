require 'netaddr'
require 'pry-byebug'

class WRTemplatesTester

  def initialize(template)
    @template = JSON.parse(File.read(template))
  end

  attr_reader :template

  def valid_cidr?(cidr_string)
    begin 
      cidr = NetAddr::CIDR.create(cidr_string)
      return true
    rescue
      return false
    end
  end

  def list_config_files(path = 'networks/configs/*')
    config_files = Dir[path]
  end

  def allowed_subnet_names()
    subnet_names_array = []
    env_addr_prefixes = []
    files = list_config_files("#{File.dirname(__FILE__)}/../../../arm_templates/networks/configs/*")
    #files = list_config_files('arm_templates/networks/configs/*') if files.empty?
    files.each do |config_file|
      config_hash = JSON.parse(File.read(config_file))
      config_hash.dig('environments').each do |env|
        unless env[1].dig('parameters', 'vNet', 'value', 'addressSpacePrefix').nil?
          unless env[1].dig('parameters', 'vNetName').nil? || env[1].dig('parameters', 'vNetName', 'value').include?('core')
            env_addr_prefixes << env[1].dig('parameters', 'vNet', 'value', 'addressSpacePrefix')
          end
        end
        unless env[1].dig('parameters', 'vNet', 'value', 'landscapes').nil?
          env[1].dig('parameters', 'vNet', 'value', 'landscapes').each do |landscape|
            landscape[1]['subnets'].each do |subnet|
              subnet_names_array << subnet.first
            end
          end
        end
      end
      unless config_hash.dig('parameters', 'vNet', 'value', 'landsacpes').nil?
        config_hash.dig('parameters', 'vNet', 'value', 'landsacpes').each do |landscape|
          landscape['subnets'].each do |subnet|
            subnet_names_array << subnet.keys.first
          end
        end
      end
    end
    subnet_names_array << 'VirtualNetwork'
    return [subnet_names_array.uniq, env_addr_prefixes] 
  end

  def disallowed_subnet_cidr?(cidr, disallowed_cidr_strings = [])
    disallowed_cidr_strings.each do |cidr_string|
      disallowed_cidr = NetAddr::CIDR.create(cidr_string)
      cidr_object = NetAddr::CIDR.create(cidr)
      result = disallowed_cidr.contains?(cidr_object)
      return result if result
    end
    return false
  end

end