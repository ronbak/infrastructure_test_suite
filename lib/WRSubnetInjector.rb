require 'json'

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
    @parameters['vNet']['value']['landscapes'].each do |landscape_name, landscape_data|
      landscape_data['subnets'].each do |subnet_name, subnet_addr|
        if @environment.eql?('core')
          built_subnets_array << build_standard_subnet_hash(landscape_name, subnet_name, subnet_addr) unless landscape_name.eql?('gateway')
          built_subnets_array << build_gateway_subnet_hash(landscape_name, subnet_name, subnet_addr) if landscape_name.eql?('gateway')
        else
          built_subnets_array << build_standard_subnet_hash(landscape_name, subnet_name, subnet_addr) unless landscape_name.eql?('gateway') || landscape_name.eql?('core')
          built_subnets_array << build_gateway_subnet_hash(landscape_name, subnet_name, subnet_addr) if landscape_name.eql?('gateway')
        end
      end
    end
    vnet_template['resources'][0]['properties']['subnets'] = built_subnets_array
    return vnet_template
  end

  def build_standard_subnet_hash(landscape_name, subnet_name, subnet_addr)
    return {
      "name" => "#{landscape_name}_#{subnet_name}",
      "properties" => {"addressPrefix" => subnet_addr,
        "networkSecurityGroup" => {
          "id" => "[resourceId('Microsoft.Network/networkSecurityGroups', 'nsg01-#{landscape_name}-#{@parameters['location_tag']['value']}-#{subnet_name}')]"
        },
        "routeTable" => {
          "id" => "[resourceId('Microsoft.Network/routeTables', concat(parameters('location_tag'), '-', parameters('environment'), '-rot-01'))]"
        }
      }
    }
  end

  def build_gateway_subnet_hash(landscape_name, subnet_name, subnet_addr)
    if subnet_name.eql?('GatewaySubnet')
      return {
        "name" => subnet_name,
        "properties" => {"addressPrefix" => subnet_addr
        }
      }
    else
      return {
        "name" => "#{@environment}_#{subnet_name}",
        "properties" => {"addressPrefix" => subnet_addr,
          "networkSecurityGroup" => {
            "id" => "[resourceId('Microsoft.Network/networkSecurityGroups', 'nsg01-#{@environment}-#{@parameters['location_tag']['value']}-#{subnet_name}')]"
          }
        }
      }
    end
  end

end
