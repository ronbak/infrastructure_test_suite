require_relative 'global_methods'
require_relative 'WRAzureCredentials'

class WRTemplateManagement

  def initialize(master_template, environment)
    @master_template = master_template
    @environment = environment
  end

  def build_templates_list(master_template)
    linked_templates = []
    master_template['resources'].select { |resource| linked_templates << resource.dig('properties', 'templateLink', 'uri') }
    linked_templates.compact
  end

  def retrieve_raw_template_data(templates_list)
    raw_templates = {}
    access_token = WRAzureCredentials.new({environment: @environment}).get_git_access_token
    templates_list.each do |template_url|
      raw_templates[template_url] = retrieve_from_github_api(convert_git_raw_to_api(template_url), access_token)
    end
    raw_templates
  end

  def convert_git_raw_to_api(url)
    github_api_url = 'https://api.github.com/repos'
    github_raw_url = 'https://raw.githubusercontent.com'
    if url[0..32] == github_raw_url
      url.sub! github_raw_url, github_api_url
      url.sub! url.split(github_api_url)[-1].split('/')[3], 'contents'
      return url
    elsif url[0..27] == github_api_url
      return url
    else
      @csrelog.error("We couldn't convert the url supplied to use GitHub api. 
        #{url}
        Please use either a github api url or a github raw.usercontent url")
      #exit 1
    end
  end

  def upload_template_to_storage(storage_account, raw_templates = {})
    # return_blobs
  end

  def create_storage()
  end

  def create_container()
  end

  def verify_storage()
  end

  def verify_container()
  end

  def retrieve_sas_token(blob)
  end

end


templates_list = build_templates_list(master_template)
raw_template_data = retrieve_raw_template_data(templates_list)
