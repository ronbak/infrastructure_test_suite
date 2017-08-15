require_relative 'global_methods'
require_relative 'CSRELogger'
require_relative 'WRAzureCredentials'
require_relative 'WRAzureResourceManagement'

class WRAzureWebServers

	def initialize(environment: nil, client_name: nil)
		log_level = 'INFO'
    log_level = ENV['CSRE_LOG_LEVEL'] unless ENV['CSRE_LOG_LEVEL'].nil?
		@csrelog = CSRELogger.new(log_level, 'STDOUT')
		options = {environment: environment, client_name: client_name}
		@credentials = WRAzureCredentials.new(options).authenticate()
		@environment = environment
		#@rg_client = Azure::ARM::Resources::ResourceManagementClient.new(@credentials)
		#@rg_client.subscription_id = wrmetadata()[@environment]['subscription_id']
    @client = WRAzureResourceManagement.new(environment: environment, client_name: client_name)
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
    cloud_service = resources.find { |resource| resource.name == cloud_service && resource.type == resource_type }
    #cloud_service = @rg_client.resources.get_by_id(cloud_service.id, '2016-11-01')
    rg_name = cloud_service.id.match('resourceGroups/(.*)/providers')[1] unless cloud_service.id.match('resourceGroups/(.*)/providers').nil?
    resources = @client.list_resources(rg_name)
    #vms = vms.select { |resource| resource.type == 'Microsoft.ClassicCompute/virtualMachines' && @rg_client.resources.get_by_id(resource.id, '2016-11-01').properties['domainName']['name'] == cloud_service.name }
    ip_list = {}
    vms = resources.each do |resource|
      if resource.type == vm_type
        @csrelog.debug("resource type matched - #{resource.name}")
        vm = @client.get_resource_by_id(resource.id)
        if vm.properties['domainName']['name'] == cloud_service.name && vm.properties['instanceView']['powerState'] == 'Started'
          @csrelog.debug("cloudService/DomainName matched - #{cloud_service.name}")
          ip_list[resource.name] = vm.properties['instanceView']['privateIpAddress']
        end
      end
    end
    return ip_list
  end

  def 

  def query_webservers_directly(host: 'www.worldremit.com', ips: [])
    query_wr_web_servers(ips, host)
  end

  def get_live_cluster()
  end

  def get_cs_from_colour(colour, env: 'prod')
    wrenvironmentdata(env)['web_clusters']['classic'][colour]['cloud_service']
  end

  def check_wr_prod_server_cluster(cluster_colour)
    cs = get_cs_from_colour(cluster_colour)
    vms_in_cs = get_vms_in_cs(cs)
    return query_webservers_directly(ips: vms_in_cs.values)
  end
end
 

# require_relative 'global_methods'
# require_relative 'CSRELogger'
# require_relative 'WRAzureCredentials'
# require_relative 'WRAzureResourceManagement'
# ENV['AZURE_CLIENT_SECRET'] = 'F9Ci6PVKnrHYoMJ2QN+iP1k/REWVuKV8N4idWhnkcGA='
# client_name = 'armTemplateAutomation'
# environment = 'dev'

# x = WRAzureResourceManagement.new(environment: 'dev', client_id: 'f03b94d9-6086-4570-808b-45b4a81af751')