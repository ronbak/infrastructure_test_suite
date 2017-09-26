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
    #access_token = WRAzureCredentials.new({environment: @environment}).get_git_access_token
    @master_template['resources'].each do |resource|
      template_url = resource['properties'].dig('templateLink', 'uri')
      if template_url
        @csrelog.debug("retrieving linked template from #{template_url}")
        # raw_template = { resource['properties']['templateLink']['uri'] => retrieve_from_github_api(convert_git_raw_to_api(template_url), access_token)}
        raw_template = { resource['properties']['templateLink']['uri'] => JSON.pretty_generate(WRConfigManager.new(config: template_url).config) }
        @csrelog.debug("uploading template to Azure Storage in #{@storage_account}/#{@templates_container}")
        if upload_template_to_storage(raw_template)
          @csrelog.debug("Updating linked template uri in master template to https://#{@storage_account}.blob.core.windows.net/#{@templates_container}/#{resource['properties']['templateLink']['uri'].split('/')[-1]}")
          resource['properties']['templateLink']['uri'] = "https://#{@storage_account}.blob.core.windows.net/#{@templates_container}/#{resource['properties']['templateLink']['uri'].split('/')[-1]}"
        end
      end
    end
    @master_template
  end

  # def retrieve_from_gitlab_api(url, access_token)
  #   uri = URI(url)
  #   https = Net::HTTP.new(uri.host, uri.port)
  #   https.use_ssl = true
  #   https.open_timeout = 5
  #   https.verify_mode = OpenSSL::SSL::VERIFY_NONE
  #   req = Net::HTTP::Get.new(uri.request_uri)
  #   req['PRIVATE-TOKEN'] = "#{access_token}"
  #   res = https.request(req)
  #   return res.body
  # end
  
  # def retrieve_repo_id_gitlab_api(repo, access_token)
  #   uri = URI("https://source.worldremit.com/api/v3/projects")
  #   https = Net::HTTP.new(uri.host, uri.port)
  #   https.use_ssl = true
  #   https.open_timeout = 5
  #   https.verify_mode = OpenSSL::SSL::VERIFY_NONE
  #   req = Net::HTTP::Get.new(uri.request_uri)
  #   req['PRIVATE-TOKEN'] = "#{access_token}"
  #   #req['Accept'] = 'application/vnd.github.v3.raw'
  #   res = https.request(req)
  #   obj = JSON.parse(res.body)
  #   return obj.find { |project| project['name'] == repo }.dig('id')
  # end

  def upload_template_to_storage(raw_templates = {})
    storer = WRAzureStorageManagement.new(environment: @environment, container: @templates_container)
    raw_templates.each do |template_name, data|
      begin
        blob_name = template_name.split('/')[-1]
        storer.upload_file_to_storage(data, blob_name)
        return true
      rescue
        @csrelog.error("the upload to Azure Storage failed for #{template_name}")
        @csrelog.debug("the failed template object name is #{template_name}
          the failed template value is: #{data}")
        return false  
      end
    end
  end

  def retrieve_sas_token(blob)
  end

end
