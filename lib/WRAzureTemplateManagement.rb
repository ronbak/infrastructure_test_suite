require 'addressable'
require 'time'
require_relative 'global_methods'
require_relative 'WRAzureCredentials'
require_relative 'WRAzureStorageManagement'
require_relative 'WRConfigManager'

class WRAzureTemplateManagement

  def initialize(master_template, environment, logger = nil)
    @master_template = master_template #Should be in hash form
    @environment = environment
    @storage_account = wrmetadata()[@environment]['storage_account']['name']
    @templates_container = 'templates' # Azure Storage container foor uploaded templates
    @csrelog = logger
  end

  def build_templates_list(master_template)
    linked_templates = []
    master_template['resources'].select { |resource| linked_templates << resource.dig('properties', 'templateLink', 'uri') }
    linked_templates.compact
  end

  def process_templates()
    @master_template['resources'].each do |resource|
      template_url = resource['properties'].dig('templateLink', 'uri')
      if template_url
        @csrelog.debug("retrieving linked template from #{template_url}")
        # raw_template = { resource['properties']['templateLink']['uri'] => retrieve_from_github_api(convert_git_raw_to_api(template_url), access_token)}
        raw_template = { resource['properties']['templateLink']['uri'] => JSON.pretty_generate(WRConfigManager.new(config: template_url).config) }
        @csrelog.debug("uploading template to Azure Storage in #{@storage_account}/#{@templates_container}")
        if upload_template_to_storage(raw_template)
          # Generate SAS token for retrieving linked templates with an expiry of 30 minutes
          canonicalized_resource = "#{@templates_container}/#{resource['properties']['templateLink']['uri'].split('/')[-1]}"
          url = create_sas_url(path: canonicalized_resource, start: (Time.now - 5*60).utc.iso8601, expiry: (Time.now + 30*60).utc.iso8601)
          @csrelog.debug("Updating linked template uri in master template to #{url}")
          resource['properties']['templateLink']['uri'] = url
        else
          @csrelog.fatal('We could not upload templates to storage, exiting')
          exit 1
        end
      end
    end
    @master_template
  end

  def upload_template_to_storage(raw_templates = {})
    storer = WRAzureStorageManagement.new(environment: @environment, container: @templates_container)
    raw_templates.each do |template_name, data|
      begin
        blob_name = template_name.split('/')[-1]
        storer.upload_file_to_storage(data, blob_name)
        return true
      rescue => e
        @csrelog.error("the upload to Azure Storage failed for #{template_name}")
        @csrelog.debug("the failed template object name is #{template_name}
          the failed template value is: #{data}")
        @csrelog.error(e)
        return false  
      end
    end
  end

  def create_signature(path = '/', resource = 'b', permissions = 'r', start = '', expiry = '', identifier = '')
    # If resource is a container, remove the last part (which is the filename)
    path = path.split('/').reverse.drop(1).reverse.join('/') if resource == 'c'
    canonicalizedResource = "/#{@storage_account}/#{path}"
    wms_api_key = WRAzureCredentials.new().get_storage_account_key
    stringToSign  = []
    stringToSign << permissions
    stringToSign << start
    stringToSign << expiry
    stringToSign << canonicalizedResource
    stringToSign << identifier
  
    stringToSign = stringToSign.join("\n")
    signature    = OpenSSL::HMAC.digest('sha256', Base64.strict_decode64(wms_api_key), stringToSign.encode(Encoding::UTF_8))
    signature    = Base64.strict_encode64(signature)
    return signature
  end
  
  def create_sas_url(path: '/', query_string: nil, resource: 'b', permissions: 'r', start: '', expiry: '', identifier: '')
    base = "https://#{@storage_account}.blob.core.windows.net"
    uri  = Addressable::URI.new
      # Parts
    parts       = {}
    parts[:st]  = URI.unescape(start) unless start == ''
    parts[:se]  = URI.unescape(expiry)
    parts[:sr]  = URI.unescape(resource)
    parts[:sp]  = URI.unescape(permissions)
    parts[:si]  = URI.unescape(identifier) unless identifier == ''
    parts[:sig] = URI.unescape( create_signature(path, resource, permissions, start, expiry) )
  
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