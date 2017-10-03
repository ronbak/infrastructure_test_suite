require 'json'
require_relative 'WRConfigManager'
require 'pry-byebug'

# Builds rules resources based on input template
class WRSubnetsArrayBuilder

  def initialize(parameters, environment, csrelogger)
    # Sanitize params input to hash
    @parameters = WRConfigManager.new(config: parameters).config
    @csrelog = csrelogger
    @environment = environment
    @parameters['subnets_array']['value'] = build_array() if verify_array_required()
  end

  attr_reader :parameters

  def verify_array_required()
    return @parameters.dig('subnets_array', 'value')[0..10] == 'build_from_' if @parameters.dig('subnets_array', 'value')
  end

  def build_array()
    if verify_array_required()
      subnets_array = []
      source_hash_name = @parameters.dig('subnets_array', 'value')[11..-1]
      source_hash = @parameters[source_hash_name]
      subnets_array = build_core_subnets_array() if @parameters.dig('vNetName', 'value').include?('core')
      source_hash['value']['landscapes'].each do |landscape_name, landscape_data|
        unless landscape_name.downcase == 'core' || landscape_name.downcase == 'gateway'
          landscape_data['subnets'].each do |subnet_name, address|
            subnets_array << { "name" => subnet_name, "landscape" => landscape_data['name'], 
              "landscapeAddressPrefix" => "[parameters('#{source_hash_name}').landscapes.#{landscape_data['name']}.addressSpacePrefix]", 
              "addressPrefix" => "[parameters('#{source_hash_name}').landscapes.#{landscape_data['name']}.subnets.#{subnet_name}]"
            }
          end
        end
      end
      return subnets_array
    end
  end

  def build_core_subnets_array()
    subnets_array = []
    source_hash_name = @parameters.dig('subnets_array', 'value')[11..-1]
    source_hash = @parameters[source_hash_name]
    source_hash['value']['landscapes'].each do |landscape_name, landscape_data|
      unless landscape_name.downcase == 'gateway'
        landscape_data['subnets'].each do |subnet_name, address|
          subnets_array << { "name" => subnet_name, "landscape" => landscape_data['name'], 
            "landscapeAddressPrefix" => "[parameters('#{source_hash_name}').landscapes.#{landscape_data['name']}.addressSpacePrefix]", 
            "addressPrefix" => "[parameters('#{source_hash_name}').landscapes.#{landscape_data['name']}.subnets.#{subnet_name}]"
          }
        end
      end
    end
    return subnets_array
  end
  
end
