require 'json'
require_relative 'WRConfigManager'
require 'pry-byebug'

# Builds rules resources based on input template
class WRAzureNsgRulesMgmt

  def initialize(parameters, templates_array, csrelogger)
    # Sanitize params input to hash
    @parameters = WRConfigManager.new(config: parameters).config
    # @template = WRConfigManager.new(config: template).config
    # @template_string = template
    @csrelog = csrelogger
    # Create hash of base rule set
    @base_resources = retrieve_resources(templates_array)
    # Check whether sourec or dest address inputs are valid
    verify_resources_params(@base_resources)
    # create hashes for each environment and subnets
    define_subnets(@parameters)
    # shorthand for location/region
    binding.pry
  end

  # Create Array of populated rules for every subnet/NSG
  def process_rules()
    resources = []
    @base_resources.each do |base_rule|
      @landscapes.each do |subnet, data|
        rule = update_rule_object(subnet, Marshal::load(Marshal.dump(base_rule)), subnet)
        resources << rule
      end
    end
    return resources
  end

  # build an array of rules resources from all the base rule templates supplied. 
  def retrieve_resources(templates_array)
    templates_files = list_template_files(templates_array)
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

  # Sanitize input to be an array of templates
  def list_template_files(templates_array)
    return templates_array if templates_array.is_a? Array
    return [templates_array] if File.file?(templates_array)
    if File.directory?(templates_array)
      templates_array += '/' unless templates_array[-1] == '/'
      return Dir["#{templates_array}*"] 
    end
    return templates_array.split(' ') if templates_array.include?(' ')
  end

  # create subnets hashes to iterate over or refer to for input rules
  def define_subnets(parameters)
    @priv_subnets = {}
    @privpart_subnets = {}
    @pubcli_subnets = {}
    @pubpart_subnets = {}
    @pub_subnets = {}
    @gateway_subnets = {}
    @core_subnets = {}
    parameters['vNet']['value']['landscapes']['core']['subnets'].each { |name, subnet| @core_subnets[name] = subnet } if parameters['vNet']['value']['landscapes'].dig('core', 'subnets')
    parameters['vNet']['value']['landscapes'].each do |landscape, value|
      @priv_subnets[value['name']] = value['subnets']['private'] if value['subnets']['private']
      @privpart_subnets[value['name']] = value['subnets']['privatepartner'] if value['subnets']['privatepartner']
      @pubcli_subnets[value['name']] = value['subnets']['publicclient'] if value['subnets']['publicclient']
      @pubpart_subnets[value['name']] = value['subnets']['publicpartner'] if value['subnets']['publicpartner']
      @pub_subnets[value['name']] = value['subnets']['public'] if value['subnets']['public']
      @gateway_subnets[value['name']] = value['subnets']['GatewaySubnet'] if value['subnets']['GatewaySubnet']
    end
    @landscapes = parameters['vNet']['value']['landscapes'].select do |landscape, value| 
      value['subnets']['private'] && value['subnets']['privatepartner'] && value['subnets']['publicclient'] && value['subnets']['publicpartner']
    end
    # This could be a params file for a core network, i.e. 
    # it does not have all of publicclient, publicpartner, private and privatepartner, if so create all landscapes that are not Gateway
    if @landscapes.empty?
      @landscapes = parameters['vNet']['value']['landscapes'].select do |landscape, value| 
         !value['subnets']['GatewaySubnet']
      end
    end
  end

  # checks to ensure any addresses referenced are valid
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

  # creates array of all subnets to create rules for
  def list_all_subnet_names(parameters)
    subnet_names = []
    parameters['vNet']['value']['landscapes'].each do |landscape, data|
      data['subnets'].each do |name, value|
        subnet_names << name
      end
    end
    return subnet_names.uniq
  end

  # retrieves the actual address prefix in CIDR notation for the given subnet and environment
  def retrieve_subnet_prefix(subnet, env)
    case subnet.downcase
    when 'private'
      return @priv_subnets[env]
    when 'privatepartner'
      return @privpart_subnets[env]
    when 'public'
      return @pub_subnets[env]
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
  
  # Updates the built rule with the correct values  
  def update_rule_object(subnet, new_rule, env)
    new_rule = update_rule_name(subnet, new_rule)
    new_rule = update_rule_addr_prefixes(subnet, new_rule, env)
    return new_rule
  end

  # Updates the address prefix to be actual subnet in CIDR notation
  def update_rule_addr_prefixes(subnet, new_rule, env)
    subnet_names_array = list_all_subnet_names(@parameters)
    new_rule['properties']['description'] += " to #{subnet}"
    new_rule['properties']['sourceAddressPrefix'] = retrieve_subnet_prefix(new_rule['properties']['sourceAddressPrefix'], env) if subnet_names_array.include?(new_rule['properties']['sourceAddressPrefix'])
    new_rule['properties']['destinationAddressPrefix'] = retrieve_subnet_prefix(new_rule['properties']['destinationAddressPrefix'], env) if subnet_names_array.include?(new_rule['properties']['destinationAddressPrefix'])
    return new_rule
  end

  # Updates the rule object name to ensure it is applied to the correct NSG
  def update_rule_name(subnet, new_rule)
    case new_rule['properties']['direction'].downcase
    when 'inbound'
      new_rule['name'] = "nsg01-#{subnet}-#{@parameters['location_tag']['value']}-#{new_rule['properties']['destinationAddressPrefix']}/" + new_rule['name']
    when 'outbound'
      new_rule['name'] = "nsg01-#{subnet}-#{@parameters['location_tag']['value']}-#{new_rule['properties']['sourceAddressPrefix']}/" + new_rule['name']
    end
    return new_rule
  end

end 
