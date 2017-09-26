require 'azure'
require_relative 'WRAzureCredentials'
require_relative 'CSRELogger'
require 'pry-byebug'

environment = 'dev'
resource_group_location = 'WestEurope'
rg_name = 'csresa-rg-dev-wr'
client_id = nil

class WRAzureStorageManagement

  def initialize(environment: nil, client_id: nil, resource_group_location: 'WestEurope', rg_name: nil, container: 'templates')
    log_level = 'INFO'
    log_level = ENV['CSRE_LOG_LEVEL'] unless ENV['CSRE_LOG_LEVEL'].nil?
    @csrelog = CSRELogger.new(log_level, 'STDOUT')
    @environment = wrenvironmentdata(environment)['name']
    # options = {environment: @environment, client_id: client_id}
    # @credentials = WRAzureCredentials.new(options).authenticate()
    # @client = Azure::ARM::Storage::StorageManagementClient.new(@credentials)
    # @client.subscription_id = wrmetadata()[@environment]['subscription_id']
    # @stor_client = Azure::ARM::Storage::StorageAccounts.new(@client)
    @storage_account = wrmetadata()[@environment]['storage_account']['name']
    @storage_access_key = 'pMgnfgYMiHYNTUAop8D0yYOFeBLQaQyvop+IOagSa9JnU3Uoum0yCtAM3vod5ooXzEa2GUhZBdX+QBFk9Ur6og=='
    Azure.config.storage_account_name = wrmetadata()[@environment]['storage_account']['name']
    Azure.config.storage_access_key = @storage_access_key
    @storage_rg = wrmetadata()[@environment]['storage_account']['resource_group']
    @resource_group_location = resource_group_location
    @container_name = container
    @azure_blob_service = Azure::Blob::BlobService.new
  end

  # def check_storage_account_exists(sa_name)
  #   if @stor_client.list.value.find { |sa| sa.name == sa_name }
  #     return true
  #   else
  #     return false
  #   end
  # end

  # def create_storage_account()
  #   parameters = Azure::ARM::Storage::Models::StorageAccountCreateParameters.new()
  #   parameters.sku = 'Standard'
  #   parameters.access_tier = 'Cool'
  #   parameters.custom_domain = @storage_account
  #   parameters.enable_https_traffic_only = true
  #   parameters.kind = 'BlobStorage'
  #   parameters.location = 'WestEurope'
  #   parameters.tags = {name: 'mySa1'}
  #   parameters.identity = @storage_account
  #   @stor_client.create('armRubyVNetTest', @storage_account, parameters)
  # end

  def create_container()
    begin
      container = @azure_blob_service.create_container(@container_name)
    rescue
      puts $!
    end
  end

  def get_container()
    @azure_blob_service.get_container_properties(@container_name)
  end

  def upload_file_to_storage(data, blob_name)
    create_container unless get_container
    blob = @azure_blob_service.create_block_blob(get_container.name,
    blob_name, data)
  end
  
end

