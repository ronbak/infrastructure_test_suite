require 'json'
require 'pry-byebug'

class WRSubnetInjector

  def initialize(vnet_template, environment, parameters)
    @environment = environment
    @parameters = parameters
    @vnet_template = vnet_template
  end

  def process_subnets()
    return add_subnets_to_existing_template(@vnet_template)
  end

  def add_subnets_to_existing_template(vnet_template)
    built_subnets_array = []
    route_table = vnet_template['resources'].find { |resource| resource['type'] == 'Microsoft.Network/routeTables' }
    route_table_name = route_table['name'].gsub('[', '').gsub(']', '')
    @parameters['vNet']['value']['landscapes'].each do |landscape_name, landscape_data|
      landscape_data['subnets'].each do |subnet_name, subnet_addr|
        # if @environment.eql?('core')
        #   built_subnets_array << build_standard_subnet_hash(landscape_name, subnet_name, subnet_addr, route_table_name) unless landscape_name.eql?('gateway')
        #   built_subnets_array << build_gateway_subnet_hash(landscape_name, subnet_name, subnet_addr) if landscape_name.eql?('gateway')
        # else
        #   built_subnets_array << build_standard_subnet_hash(landscape_name, subnet_name, subnet_addr, route_table_name) unless landscape_name.eql?('gateway') || landscape_name.eql?('core')
        #   built_subnets_array << build_gateway_subnet_hash(landscape_name, subnet_name, subnet_addr) if landscape_name.eql?('gateway')
        # end
        if @environment.eql?('core')
          built_subnets_array << build_subnet_hash(landscape_name, subnet_name, subnet_addr, route_table_name) 
        else
          built_subnets_array << build_subnet_hash(landscape_name, subnet_name, subnet_addr, route_table_name) unless landscape_name.eql?('core')
        end
      end
    end
    vnet_template['resources'][0]['properties']['subnets'] = built_subnets_array
    return vnet_template
  end

  # def build_standard_subnet_hash(landscape_name, subnet_name, subnet_addr, route_table_name)
  #   return {
  #     "name" => "#{landscape_name}-#{subnet_name}",
  #     "properties" => {"addressPrefix" => subnet_addr,
  #       "networkSecurityGroup" => {
  #         "id" => "[resourceId('Microsoft.Network/networkSecurityGroups', 'nsg01-#{landscape_name}-#{@parameters['location_tag']['value']}-#{subnet_name}')]"
  #       },
  #       "routeTable" => {
  #         "id" => "[resourceId('Microsoft.Network/routeTables', #{route_table_name})]"
  #       }
  #     }
  #   }
  # end

  # def build_gateway_subnet_hash(landscape_name, subnet_name, subnet_addr)
  #   if subnet_name.eql?('GatewaySubnet')
  #     return {
  #       "name" => subnet_name,
  #       "properties" => {"addressPrefix" => subnet_addr
  #       }
  #     }
  #   else
  #     return {
  #       "name" => "#{@environment}-#{subnet_name}",
  #       "properties" => {"addressPrefix" => subnet_addr,
  #         "networkSecurityGroup" => {
  #           "id" => "[resourceId('Microsoft.Network/networkSecurityGroups', 'nsg01-#{@environment}-#{@parameters['location_tag']['value']}-#{subnet_name}')]"
  #         }
  #       }
  #     }
  #   end
  # end

  def build_subnet_hash(landscape_name, subnet_name, subnet_addr, route_table_name)
    #binding.pry
    if subnet_name.eql?('GatewaySubnet')
      complete_subnet_name = subnet_name
    elsif landscape_name.eql?('gateway')
      complete_subnet_name = "#{@environment}-#{subnet_name}"
    else
      complete_subnet_name = "#{landscape_name}-#{subnet_name}"
    end
    subnet_hash = {
      "name" => complete_subnet_name,
      "properties" => {"addressPrefix" => subnet_addr
      }
    }
    unless wrmetadata()['global']['subnets']['no_nsg'].include?(subnet_name) || wrmetadata()['global']['subnets']['no_nsg'].include?(complete_subnet_name)
      subnet_hash['properties']['networkSecurityGroup'] = {"id" => "[resourceId('Microsoft.Network/networkSecurityGroups', 'nsg01-#{@environment}-#{@parameters['location_tag']['value']}-#{subnet_name}')]"} if landscape_name.eql?('gateway')
      subnet_hash['properties']['networkSecurityGroup'] = {"id" => "[resourceId('Microsoft.Network/networkSecurityGroups', 'nsg01-#{landscape_name}-#{@parameters['location_tag']['value']}-#{subnet_name}')]"} unless landscape_name.eql?('gateway')
    end
    unless landscape_name.eql?('gateway') || wrmetadata()['global']['subnets']['no_routetable'].include?(subnet_name) || wrmetadata()['global']['subnets']['no_routetable'].include?(complete_subnet_name)
      subnet_hash['properties']['routeTable'] = {"id" => "[resourceId('Microsoft.Network/routeTables', #{route_table_name})]"}
    end
    return subnet_hash
  end

end
