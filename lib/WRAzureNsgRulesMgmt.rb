require 'json'
require_relative 'WRConfigManager'
require 'pry-byebug'

class WRAzureNsgRulesMgmt

  def initialize(parameters, templates_string, csrelogger)
    @parameters = WRConfigManager.new(config: parameters).config
    # @template = WRConfigManager.new(config: template).config
    # @template_string = template
    @csrelog = csrelogger
    @base_resources = retrieve_resources(templates_string)
    verify_resources_params(@base_resources)
    define_subnets(@parameters)
  end

  def retrieve_resources(templates_string)
    templates_files = list_template_files(templates_string)
    resources_array = []
    if templates_files.nil?
      @csrelog.fatal("There are no JSON rules templates to process")
      exit 1
    end
    templates_files.each do |template|
      template_hash = WRConfigManager.new(config: template).config
      resources_array += template_hash['resources']
    end
    return resources_array.uniq
  end

  def list_template_files(templates_string)
    return [templates_string] if File.file?(templates_string)
    return Dir["#{templates_string += '/' unless templates_string[-1] == '/'}*"] if File.directory?(templates_string)
    return templates_string.split(' ') if templates_string.include?(' ')
  end

  def define_subnets(parameters)
    @priv_subnets = {}
    @privpart_subnets = {}
    @pubcli_subnets = {}
    @pubpart_subnets = {}
    @gateway_subnets = {}
    @core_subnets = {}
    parameters['vNet']['value']['landscapes']['core']['subnets'].each { |name, subnet| @core_subnets[name] = subnet } if parameters['vNet']['value']['landscapes'].dig('core', 'subnets')
    parameters['vNet']['value']['landscapes'].each do |landscape, value|
      @priv_subnets[value['name']] = value['subnets']['private'] if value['subnets']['private']
      @privpart_subnets[value['name']] = value['subnets']['privatepartner'] if value['subnets']['privatepartner']
      @pubcli_subnets[value['name']] = value['subnets']['publicclient'] if value['subnets']['publicclient']
      @pubpart_subnets[value['name']] = value['subnets']['publicpartner'] if value['subnets']['publicpartner']
      @gateway_subnets[value['name']] = value['subnets']['GatewaySubnet'] if value['subnets']['GatewaySubnet']
    end
    @landscapes = parameters['vNet']['value']['landscapes'].select do |landscape, value| 
      value['subnets']['private'] && value['subnets']['privatepartner'] && value['subnets']['publicclient'] && value['subnets']['publicpartner']
    end
  end

  def verify_resources_params(resources)
    subnet_names_array = list_all_subnet_names(@parameters)
    resources.each do |resource|
      case resource['properties']['direction'].downcase
      when 'inbound'
        verify_resources_addrprefix_inbound(resource, subnet_names_array)
      when 'outbound'
        verify_resources_addrprefix_outbound(resource, subnet_names_array)
      end
    end
  end

  def verify_resources_addrprefix_inbound(resource, subnet_names_array)
    unless subnet_names_array.include?(resource['properties']['destinationAddressPrefix']) then
      @csrelog.fatal("Your inbound rule has specified an incorrect destination address prefix.
        Inbound rules require that the destination address be the subnet to which this rule is being applied
        Please use one of #{subnet_names_array}")
      @csrelog.fatal(JSON.pretty_generate(resource))
      exit 1
    end
  end

  def verify_resources_addrprefix_outbound(resource, subnet_names_array)
    unless subnet_names_array.include?(resource['properties']['sourceAddressPrefix']) then
      @csrelog.fatal("Your outbound rule has specified an incorrect source address prefix.
        Outbound rules require that the source address be the subnet to which this rule is being applied
        Please use one of #{subnet_names_array}")
      @csrelog.fatal(JSON.pretty_generate(resource))
      exit 1
    end
  end

  def list_all_subnet_names(parameters)
    subnet_names = []
    parameters['vNet']['value']['landscapes'].each do |landscape, data|
      data['subnets'].each do |name, value|
        subnet_names << name
      end
    end
    return subnet_names.uniq
  end

  def retrieve_subnet_prefix(subnet, env)
    case subnet.downcase
    when 'private'
      return @priv_subnets[env]
    when 'privatepartner'
      return @privpart_subnets[env]
    when 'publicclient'
      return @pubcli_subnets[env]
    when 'publicpartner'
      return @pubpart_subnets[env]
    when 'gatewaysubnet'
      return @gateway_subnets['GatewaySubnet']
    when 'coreprivate'
      return @core_subnets['coreprivate']
    when 'corepublic'
      return @core_subnets['corepublic']
    end
  end
  
  def update_rule_object(subnet, new_rule, env)
    new_rule = update_rule_name(subnet, new_rule)
    new_rule = update_rule_addr_prefixes(subnet, new_rule, env)
    return new_rule
  end

  def update_rule_addr_prefixes(subnet, new_rule, env)
    subnet_names_array = list_all_subnet_names(@parameters)
    new_rule['properties']['description'] += " to #{subnet}"
    new_rule['properties']['sourceAddressPrefix'] = retrieve_subnet_prefix(new_rule['properties']['sourceAddressPrefix'], env) if subnet_names_array.include?(new_rule['properties']['sourceAddressPrefix'])
    new_rule['properties']['destinationAddressPrefix'] = retrieve_subnet_prefix(new_rule['properties']['destinationAddressPrefix'], env) if subnet_names_array.include?(new_rule['properties']['destinationAddressPrefix'])
    return new_rule
  end

  def update_rule_name(subnet, new_rule)
    case new_rule['properties']['direction'].downcase
    when 'inbound'
      new_rule['name'] = "#{subnet}_#{new_rule['properties']['destinationAddressPrefix']}-nsg/" + new_rule['name']
    when 'outbound'
      new_rule['name'] = "#{subnet}_#{new_rule['properties']['sourceAddressPrefix']}-nsg/" + new_rule['name']
    end
    return new_rule
  end

  def process_rules()
    resources = []
    @base_resources.each do |base_rule|
      @landscapes.each do |subnet, data|
        rule = update_rule_object(subnet, Marshal::load(Marshal.dump(base_rule)), subnet)
        resources << rule
      end
    end
    return resources
    #write_config_to_disk(JSON.pretty_generate(template), 'generated_rules.json')
  end
end
