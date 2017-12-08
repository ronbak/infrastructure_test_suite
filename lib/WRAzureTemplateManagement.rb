require 'addressable'
require 'time'
require 'pry-byebug'
require_relative 'global_methods'
require_relative 'WRAzureCredentials'
require_relative 'WRAzureStorageManagement'
require_relative 'WRConfigManager'
require_relative 'WRAzureNsgRulesMgmt'
require_relative 'WRSubnetInjector'

class WRAzureTemplateManagement

  def initialize(master_template, environment, rules_template, parameters, output, no_upload = false, logger = nil)
    @master_template = master_template #Should be in hash form
    @environment = environment
    @rules_template = rules_template
    @parameters = parameters
    @storage_account = wrmetadata()[@environment]['storage_account']['name']
    @templates_container = wrmetadata().dig(@environment, 'storage_account', 'templates_container') # 'templates' # Azure Storage container foor uploaded templates
    @container_access_policy = wrmetadata().dig(@environment, 'storage_account', 'container_access_policy') 
    @csrelog = logger
    @output = output
    @no_upload = no_upload
    @access_policy_id = 'saslinkedtemplates'
  end

  def build_templates_list(master_template)
    linked_templates = []
    master_template['resources'].select { |resource| linked_templates << resource.dig('properties', 'templateLink', 'uri') }
    linked_templates.compact
  end

  def process_templates()
    @master_template = sanitize_template_params(@master_template)
    @master_template['resources'].each do |resource|
      template_url = resource['properties'].dig('templateLink', 'uri')
      if template_url
        @csrelog.debug("retrieving linked template from #{template_url}")
        # raw_template = { resource['properties']['templateLink']['uri'] => retrieve_from_github_api(convert_git_raw_to_api(template_url), access_token)}
        raw_template = { resource['properties']['templateLink']['uri'] => JSON.pretty_generate(WRConfigManager.new(config: template_url).config) }
        # inject the rules into the nsg template
        raw_template = inject_rules_to_template(@rules_template, raw_template) if @rules_template 
        # Inject subnets directly in to the VNets template - to maintain subnet state during redeploys
        raw_template = inject_subnets_to_template(raw_template)
        # Inject parameters in to linked template to ensure it matches the master template
        raw_template = inject_parameters_to_template(raw_template, @master_template['parameters'])
        # write linked templates to disk for testing
        if @output 
          output_file_name =  if @output.include?('/')
                                folder_path = @output.gsub(@output.split('/')[-1], '')
                                folder_path + @output.split('/')[-1].split('.')[0] + '.' + raw_template.keys.first.split('/')[-1]
                              else
                                @output.split('/')[-1].split('.')[0] + '.' + raw_template.keys.first.split('/')[-1]
                              end
          write_hash_to_disk(JSON.parse(raw_template.values.first), output_file_name)                              
        end
        unless @no_upload
          # upload linked templates to Azure storage
          @csrelog.debug("uploading template to Azure Storage in #{@storage_account}/#{@templates_container}")
          blob_name = upload_template_to_storage(raw_template)
          if blob_name
            # Generate SAS token for retrieving linked templates with an expiry of 30 minutes
            canonicalized_resource = "#{@templates_container}/#{blob_name}"
            url = create_sas_url(path: canonicalized_resource, identifier: @container_access_policy)
            @csrelog.debug("Updating linked template uri in master template to #{url}")
            resource['properties']['templateLink']['uri'] = url
          else
            @csrelog.fatal('We could not upload templates to storage, exiting')
            exit 1
          end
        end
      end
    end
    @master_template
  end

  def sanitize_template_params(template)
    linked_template_params_hash = {}
    params = template.dig('parameters')
    params = params.each do |param_name, value|
      unless value.dig('defaultValue')
        case value['type'].downcase
        when 'string'
          value['defaultValue'] = ""
        when 'array'
          value['defaultValue'] = []
        when 'object'
          value['defaultValue'] = {}
        when 'securestring'
          value['defaultValue'] = ""
        when 'bool'
          value['defaultValue'] = false
        end
      end
      linked_template_params_hash[param_name] = {"value" => "[parameters('#{param_name}')]"}
    end
    
    template['resources'].each do |resource|
      if resource.dig('properties', 'parameters') && resource.dig('properties', 'templateLink')
        resource['properties']['parameters'] = linked_template_params_hash
      end
    end
    return template
  end

  def inject_rules_to_template(rules_array, raw_template)
    nsg_template = JSON.parse(raw_template.values[0])
    if nsg_template.dig('variables', 'inject_rules_here')
      nsg_template = WRAzureNsgRulesMgmt.new(@parameters, rules_array, nsg_template, @csrelog).process_rules
      raw_template[raw_template.keys[0]] = JSON.pretty_generate(nsg_template)
      return raw_template
    end
    return raw_template
  end

  def inject_subnets_to_template(raw_template)
    vnet_template = JSON.parse(raw_template.values[0])
    if vnet_template.dig('variables', 'inject_subnets_here')
      vnet_template = WRSubnetInjector.new(vnet_template, @environment, @parameters).process_subnets
      raw_template[raw_template.keys[0]] = JSON.pretty_generate(vnet_template)
      return raw_template
    end
    return raw_template
  end

  def inject_parameters_to_template(raw_template, params_hash)
    template = JSON.parse(raw_template.values[0])
    template['parameters'] = template['parameters'].deep_merge(params_hash)
    raw_template[raw_template.keys[0]] = JSON.pretty_generate(template)
    return raw_template
  end

  def upload_template_to_storage(raw_templates = {})
    storer = WRAzureStorageManagement.new(environment: @environment, container: @templates_container)
    raw_templates.each do |template_name, data|
      begin
        blob_name = template_name.split('/')[-1] + '.' + Time.now().strftime("%d%m%Y%H%M%S")
        storer.upload_file_to_storage(data, blob_name)
        return blob_name
      rescue => e
        @csrelog.error("the upload to Azure Storage failed for #{template_name}")
        @csrelog.debug("the failed template object name is #{template_name}
          the failed template value is: #{data}")
        @csrelog.error(e)
        return false  
      end
    end
  end

  def create_signature(permissions = 'r', start = '', expiry = '', path = '/', identifier = '', ip = '', protocol = '', version = '', rscc = '', rscd = '', rsce = '', rscl = '', rsct = '')
    # If resource is a container, remove the last part (which is the filename)
    #path = path.split('/').reverse.drop(1).reverse.join('/') if resource == 'c'
    canonicalizedResource = "/blob/#{@storage_account}/#{path}"
    wms_api_key = WRAzureCredentials.new(environment: @environment).get_storage_account_key
    stringToSign  = []
    stringToSign << permissions
    stringToSign << start
    stringToSign << expiry
    stringToSign << canonicalizedResource
    stringToSign << identifier
    stringToSign << ip
    stringToSign << protocol
    stringToSign << version
    stringToSign << rscc
    stringToSign << rscd
    stringToSign << rsce
    stringToSign << rscl
    stringToSign << rsct
  
    stringToSign = stringToSign.join("\n")
    signature = OpenSSL::HMAC.digest('sha256', Base64.strict_decode64(wms_api_key), stringToSign.encode(Encoding::UTF_8))
    signature    = Base64.strict_encode64(signature)
    return signature
  end

  def create_sas_url(path: '/', query_string: nil, resource: 'b', permissions: 'r', start: '', expiry: '', identifier: '')
    base = "https://#{@storage_account}.blob.core.windows.net"
    uri  = Addressable::URI.new
      # Parts
    parts       = {}
    parts[:sv]  = URI.unescape('2015-04-05')
    #parts[:st]  = URI.unescape(start) unless start == ''
    parts[:sr]  = URI.unescape(resource)
    #parts[:se]  = URI.unescape(expiry)
    #parts[:sp]  = URI.unescape(permissions)
    parts[:si]  = URI.unescape(identifier) unless identifier == ''
    parts[:sig] = URI.unescape( create_signature('', '', '', path, identifier, '', '', '2015-04-05', '', '', '', '', '') )
  
    uri.query_values = parts
    return "#{base}/#{path}?#{uri.query}"
  end

end



           

# url = createSignedQueryString(
#   'templates/nsgs.json',
#   nil,
#   'b', 
#   'r', 
#   (Time.now - 5*60).utc.iso8601, 
#   (Time.now + 30*60).utc.iso8601
# )