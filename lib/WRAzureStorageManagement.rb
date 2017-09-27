require 'azure'
require_relative 'WRAzureCredentials'
require_relative 'CSRELogger'
require 'pry-byebug'

class WRAzureStorageManagement

  def initialize(environment: nil, client_id: nil, resource_group_location: 'WestEurope', rg_name: nil, container: 'templates')
    log_level = 'INFO'
    log_level = ENV['CSRE_LOG_LEVEL'] unless ENV['CSRE_LOG_LEVEL'].nil?
    @csrelog = CSRELogger.new(log_level, 'STDOUT')
    @environment = wrenvironmentdata(environment)['name']
    @storage_account = wrmetadata()[@environment]['storage_account']['name']
    @storage_access_key = WRAzureCredentials.new().get_storage_account_key
    Azure.config.storage_account_name = wrmetadata()[@environment]['storage_account']['name']
    Azure.config.storage_access_key = @storage_access_key
    @storage_rg = wrmetadata()[@environment]['storage_account']['resource_group']
    @resource_group_location = resource_group_location
    @container_name = container
    @azure_blob_service = Azure::Blob::BlobService.new
  end

  def create_container()
    begin
      container = @azure_blob_service.create_container(@container_name)
    rescue
      puts $!
    end
  end

  def get_container()
    begin
      @azure_blob_service.get_container_properties(@container_name)
    rescue
      false
    end
  end

  def upload_file_to_storage(data, blob_name)
    create_container unless get_container
    blob = @azure_blob_service.create_block_blob(get_container.name,
    blob_name, data)
  end
  
end
