require 'azure_mgmt_storage'
require_relative 'WRAzureCredentials'
require_relative 'CSRELogger'
require 'pry-byebug'

class WRAzureStorageManagement

  def initialize(environment: nil, client_id: nil, resource_group_location: 'WestEurope', rg_name: nil)
    log_level = 'INFO'
    log_level = ENV['CSRE_LOG_LEVEL'] unless ENV['CSRE_LOG_LEVEL'].nil?
    @csrelog = CSRELogger.new(log_level, 'STDOUT')
    @environment = wrenvironmentdata(environment)['name']
    options = {environment: @environment, client_id: client_id}
    @credentials = WRAzureCredentials.new(options).authenticate()
    @client = Azure::ARM::Storage::StorageManagementClient.new(@credentials)
    #@client.subscription_id = wrmetadata()[@environment]['subscription_id']
    @resource_group_location = resource_group_location
    @rg_name = rg_name
  end

  
end
