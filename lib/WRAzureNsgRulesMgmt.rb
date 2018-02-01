require 'json'
require_relative 'WRConfigManager'
require 'pry-byebug'

# Builds rules resources based on input template
class WRAzureNsgRulesMgmt

  def initialize(parameters, templates_array, nsg_template, csrelogger)
    # Sanitize params input to hash
    @parameters = WRConfigManager.new(config: parameters).config
    # Get template
    @template = WRConfigManager.new(config: nsg_template).config
    # @template_string = template
    @csrelog = csrelogger
    # Create hash of base rule set
    @base_resources = retrieve_resources(templates_array)
    # Check whether sourec or dest address inputs are valid
    verify_resources_params(@base_resources)
    # create hashes for each environment and subnets
    define_subnets(@parameters)
  end

  attr_reader :base_resources
  attr_reader :priv_subnets
  attr_reader :privpart_subnets
  attr_reader :pubcli_subnets
  attr_reader :pubpart_subnets
  attr_reader :gateway_subnets
  attr_reader :core_subnets
  attr_reader :landscapes

  # Create Array of populated rules for every subnet/NSG
  def process_rules()
    # extract base NSG resource object from the template
    base_nsg_object = @template['resources'].first
    # delete the extracted resource fro the template
    @template['resources'].delete(base_nsg_object)
    # Loop through each subnet in the subnets_array
    @parameters['subnets_array']['value'].each do |subnet|
      # create the NSG resource object for the subnet
      nsg = create_nsg_object(subnet, Marshal::load(Marshal.dump(base_nsg_object)))
      # Inject all of the rules for the given subnet in to the NSG resource / object.
      nsg = inject_rules_into_nsg(nsg, subnet)
      @template['resources'] << nsg
    end
    return @template
  end

  def create_nsg_object(subnet, base_nsg_object)
    base_nsg_object['name'] = "nsg01-#{subnet['landscape']}-#{@parameters['location_tag']['value']}-#{subnet['name']}"
    base_nsg_object['condition'] = base_nsg_object['condition'].gsub("parameters('subnets_array')[copyIndex()].name", "'#{subnet['name']}'")
    base_nsg_object.delete('copy')
    base_nsg_object.dig('properties', 'securityRules').each do |rule|
      rule.dig('properties').each do |property|
        if property[1].kind_of?(String) && property[1].include?('[copyIndex()]')
          value_to_lookup = property[1].split('[copyIndex()].')[-1].gsub(']', '')
          rule['properties'][property[0]] = subnet[value_to_lookup]
        end
      end
    end
    return base_nsg_object
  end

  def inject_rules_into_nsg(nsg, subnet)
    rules_to_apply = @base_resources.select { |rule| rule['properties']['destinationAddressPrefix'] == subnet['name'] }
    rules_to_apply.each do |base_rule|
      rule = update_rule_object(subnet['landscape'], Marshal::load(Marshal.dump(base_rule)))
      rule.delete('apiVersion')
      rule.delete('location')
      rule.delete('type')
      rule['name'] = rule['name'].split('/')[-1]
      if condition_met?(nsg, rule)
        rule.delete('condition')
        nsg['properties']['securityRules'] << rule
      end
    end
    return nsg
  end

  def condition_met?(nsg, rule)
    condition = rule.dig('condition')
    if condition
      comparison, container, element = clean_condition(condition)
      container = resolve_comparison_container(nsg, container)
      case comparison
      when 'equal'
        return container.eql?(element)
      when 'not_equal'
        return !container.eql?(element)
      when 'contains'
        return container.include?(element)
      when 'not_contains'
        return !container.include?(element)
      end
      return false
    end
    return true
  end

  def clean_condition(condition)
    functions = ['not', 'and']
    comparison = condition.split('(')[0].split('[')[-1]
    if functions.include?(comparison)
      function = condition.split('(')[0].split('[')[-1]
      comparison = function + '_' + condition.split(function)[1].split('(')[1]
      container = condition.split("#{function}(")[1].match(/\((.*?)\)/)[1].split(', ')[0]
    else
      container = condition.match(/\((.*?)\)/)[1].split(', ')[0]
    end
    element = condition.match(/\((.*?)\)/)[1].split(', ')[-1]
    element = element[1..-2] if element.match(/'(.*)'/)
    return [comparison, container, element]
  end

  def resolve_comparison_container(nsg, container)
    resource_string = container.split('/')[0]
    resource_element = container.split('/')[1]
    case resource_string
    when 'parent_resource'
      resource = nsg
    end
    return resource[resource_element] if resource_element
    return resource
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
  def retrieve_subnet_prefix(subnet_name, env)
    local_addr = @parameters['vNet']['value']['landscapes'][env]['subnets'][subnet_name]
    return local_addr unless local_addr.nil?
    obj = @parameters['vNet']['value']['landscapes'].select { |landscape, landscape_data| landscape_data['subnets'].include?(subnet_name)}
    return obj.values[0]['subnets'][subnet_name] unless obj.nil? || obj.count != 1
  end
  
  # Updates the built rule with the correct values  
  def update_rule_object(env, new_rule)
    new_rule = update_rule_name(env, new_rule)
    new_rule = update_rule_addr_prefixes(env, new_rule)
    return new_rule
  end

  # Updates the address prefix to be actual subnet in CIDR notation
  def update_rule_addr_prefixes(env, new_rule)
    subnet_names_array = list_all_subnet_names(@parameters)
    new_rule['properties']['description'] += " to #{env}"
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
