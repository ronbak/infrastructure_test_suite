require_relative 'global_methods'
require_relative 'CSRELogger'
require_relative 'WRAzureCredentials'
require_relative 'WRAzureResourceManagement'

class WRAzureWebServers

	def initialize(environment: nil, client_name: nil)
		log_level = 'INFO'
    log_level = ENV['CSRE_LOG_LEVEL'] unless ENV['CSRE_LOG_LEVEL'].nil?
		@csrelog = CSRELogger.new(log_level, 'STDOUT')
    @environment = wrenvironmentdata(environment)['name']
		options = {environment: @environment, client_name: client_name}
		@credentials = WRAzureCredentials.new(options).authenticate()
		#@rg_client = Azure::ARM::Resources::ResourceManagementClient.new(@credentials)
		#@rg_client.subscription_id = wrmetadata()[@environment]['subscription_id']
    @client = WRAzureResourceManagement.new(environment: @environment, client_name: client_name)
	end

	def get_vms_in_cs(cloud_service, type: 'classic')
    case type.downcase
    when 'classic'
      resource_type = 'Microsoft.ClassicCompute/domainNames'
      vm_type = 'Microsoft.ClassicCompute/virtualMachines'
    when 'resourcemanager'
      resource_type = 'Microsoft.Compute/domainNames'
      vm_type = 'Microsoft.Compute/virtualMachines'
    end
    resources = @client.list_all_resources()
    cloud_service = resources.find { |resource| resource.name.downcase() == cloud_service.downcase() && resource.type == resource_type }
    @csrelog.error("We could not find the cloud service in the list of all rsources in this environment: #{@environment}") if cloud_service.nil?
    return nil if cloud_service.nil?
    rg_name = cloud_service.id.match('resourceGroups/(.*)/providers')[1] unless cloud_service.id.match('resourceGroups/(.*)/providers').nil?
    resources = @client.list_resources(rg_name)
    ip_list = {}
    vms = resources.each do |resource|
      if resource.type == vm_type
        @csrelog.debug("resource type matched - #{resource.name}")
        Thread.new{
          vm = @client.get_resource_by_id(resource.id)
          if vm.properties['domainName']['name'] == cloud_service.name && vm.properties['instanceView']['powerState'] == 'Started'
            @csrelog.debug("cloudService/DomainName matched - #{cloud_service.name}")
            ip_list[resource.name] = vm.properties['instanceView']['privateIpAddress']
          end
        }
      end
    end
    return ip_list
  end

  def query_webservers_directly(host: 'www.worldremit.com', ips: [])
    query_wr_web_servers(ips, host)
  end

  def get_live_cloud_service()
    x = @client.get_resource_by_id("/subscriptions/76d26251-cc91-46f7-9459-4bc76ea9a2ae/resourceGroups/Default-TrafficManager/providers/Microsoft.Network/trafficmanagerprofiles/WorldRemit", api_version: '2017-05-01')
    live_service = x.properties['endpoints'].find { |ep| ep['properties']['endpointStatus'] == "Enabled" && ep['properties']['endpointMonitorStatus'] == "Online" }
    cloud_service = live_service['properties']['targetResourceId'].split('/')[-1]
  end

  def get_colour_from_cs(cloud_service)
     obj = wrenvironmentdata(@environment)['web_clusters']['classic'].find { |cs| cs[1]['cloud_service'] == cloud_service.downcase() }
     return obj[0] unless obj.nil?
  end

  def get_cs_from_colour(colour)
    wrenvironmentdata(@environment)['web_clusters']['classic'][colour]['cloud_service']
  end

  def check_wr_web_server_cluster(cloud_service)
    #cloud_service = get_cs_from_colour(cluster_colour)
    vms_in_cs = get_vms_in_cs(cloud_service)
    return query_webservers_directly(ips: vms_in_cs.values)
  end

  def check_wr_web_servers()
    cloud_service = get_live_cloud_service()
    return check_wr_web_server_cluster(cloud_service)
  end

  def get_live_colour()
    cloud_service = get_live_cloud_service()
    return get_colour_from_cs(cloud_service)
  end

end
