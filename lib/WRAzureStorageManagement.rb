require 'azure'
require_relative 'WRAzureCredentials'
require_relative 'CSRELogger'
require 'pry-byebug'
require 'azure/service/signed_identifier'


class WRAzureStorageManagement

  def initialize(environment: nil, client_id: nil, resource_group_location: 'WestEurope', rg_name: nil, container: 'templates')
    log_level = 'INFO'
    log_level = ENV['CSRE_LOG_LEVEL'] unless ENV['CSRE_LOG_LEVEL'].nil?
    @csrelog = CSRELogger.new(log_level, 'STDOUT')
    @environment = wrenvironmentdata(environment)['name']
    @storage_account = wrmetadata()[@environment]['storage_account']['name']
    @storage_access_key = WRAzureCredentials.new(environment: environment).get_storage_account_key
    Azure.config.storage_account_name = wrmetadata()[@environment]['storage_account']['name']
    Azure.config.storage_access_key = @storage_access_key
    #@storage_rg = wrmetadata()[@environment]['storage_account']['resource_group']
    @resource_group_location = resource_group_location
    @container_name = container
    @azure_blob_service = Azure::Blob::BlobService.new
  end


  def set_access_policy_expiry(policy_id, minutes_to_add = 30)
    # Some code here. Create blobs instance.
    # blobs = Azure::Blob::BlobService.new
    sas = Azure::Service::SignedIdentifier.new
    sas.id = policy_id
    policy = sas.access_policy
    policy.start = (Time.now - 5 * 60).utc.iso8601
    policy.expiry = (Time.now + minutes_to_add*60).utc.iso8601
    policy.permission = "r"
    identifiers = [sas]
    options = { timeout: 60, signed_identifiers: identifiers }
    container, signed = @azure_blob_service.set_container_acl(@container_name, "", options)
  end



  def delete_old_blobs
    blobs = list_blobs()
    while blobs.count >= 61
      blobs = sort_by_datetime(blobs)
      last_blobs = []
      last_blobs += blobs[0..5]
      last_blobs.each do |blob_to_delete|
        delete_blob(@container_name, blob_to_delete.name)
        sleep 0.2 # to prevent throttling on requests
      end
      blobs = list_blobs()
    end
  end

  def sort_by_datetime(blobs, direction="ASC")
    return blobs.sort_by { |blob| direction == "DESC" ? -DateTime.parse(blob.properties[:last_modified]).to_i : DateTime.parse(blob.properties[:last_modified]) }
  end

  def get_blobs_older_than(date_to_delete, blobs)
    return blobs.select { |blob| DateTime.parse(blob.properties[:last_modified]) <= date_to_delete }
  end

  def get_blobs_newer_than(date_to_delete, blobs)
    return blobs.select { |blob| DateTime.parse(blob.properties[:last_modified]) >= date_to_delete }
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

  def get_oldest_blob(blobs)
    return blobs.min_by { |blob| DateTime.parse(blob.properties[:last_modified]) }
  end

  def list_blobs
    return @azure_blob_service.list_blobs(@container_name)
  end

  def upload_file_to_storage(data, blob_name)
    create_container unless get_container
    blob = @azure_blob_service.create_block_blob(get_container.name,
      blob_name, data)
    delete_old_blobs()
  end

  def delete_blob(container, blob)
    @azure_blob_service.delete_blob(container, blob)
  end

  def delete_container(container)
    @azure_blob_service.delete_container(container)
  end
end
