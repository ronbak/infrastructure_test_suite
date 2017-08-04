require_relative 'global_methods'
require_relative 'WRAzureCredentials'
require 'azure_mgmt_network'

class WRAzureNetworkManagement

	def initialize(environment: nil, client_id: nil)
		options = {environment: environment, client_id: client_id}
		@credentials = WRAzureCredentials.new(options).authenticate()
		@environment = environment
		@client = Azure::ARM::Network::NetworkManagementClient.new(@credentials)
		@client.subscription_id = wrmetadata()[@environment]['subscription_id']
	end

	def list_resource_groups()
		response = @client.subnets.list('armtestnetwork1', 'armtestvnet1')
		@client.subnets.get('armtestnetwork1', 'armtestvnet1', 'subnet-1')
		resources_array = []
		response.each do |rg|
			resources_array << rg.name
		end
		return resources_array
	end

	def list_available_ips(resource_group: nil, vnet: nil)
		subnets = @client.subnets.list(resource_group, vnet)
		vnet_ip_availability = {}
		subnets.each do |subnet|
			#puts "\nQuerying #{subnet.name}\n"
			ips_to_check = []
			available_ips = []
			ip_addr_space = IPAddr.new subnet.address_prefix
			ip_addr_space.to_range.each do |ip|
				ips_to_check << ip.to_s
			end
			ips_to_check.each do |ip|
				if ips_to_check.include?(ip)
					#puts "checking IP: #{ip}"
				  resp = @client.virtual_networks.check_ipaddress_availability(resource_group, vnet, ip)
				  available_ips << ip if resp.available
				  unless resp.available
				  	resp.available_ipaddresses.each do |ip|
				  		available_ips << ip unless available_ips.include?(ip)
				  		ips_to_check.delete(ip)
				  	end
				 end
			  end
			end
			vnet_ip_availability[subnet.name] = available_ips.count
			puts "there are: #{available_ips.count} available IP addresses in #{subnet.name}"
	  end
	  return vnet_ip_availability
  end

end

# resource_group = 'armtestnetwork1'
# vnet = 'armtestvnet1'
 

# # ENV['AZURE_CLIENT_SECRET'] = 'F9Ci6PVKnrHYoMJ2QN+iP1k/REWVuKV8N4idWhnkcGA='
# # x = WRAzureResourceManagement.new(environment: 'dev', client_id: 'f03b94d9-6086-4570-808b-45b4a81af751')

# rg_name = 'armtestnetwork1'
# nic_name = 'TestCSRENic2'

# ip_config = Azure::ARM::Network::Models::NetworkInterfaceIPConfiguration.new()
# ip_config.private_ipaddress = '10.3.0.10'
# ip_config.name = 'NicIPConfig2'
# ip_config.private_ipaddress_version = 'IPv4'
# ip_config.private_ipallocation_method = 'Static'
# ip_config.primary = true
# ip_config.subnet = Azure::ARM::Network::Models::Subnet.new()
# ip_config.subnet.id = "/subscriptions/520d638a-7b1b-4143-a625-fcf6e0f59fcf/resourceGroups/armtestnetwork1/providers/Microsoft.Network/virtualNetworks/armtestvnet1/subnets/subnet-1"


# dns_settings = Azure::ARM::Network::Models::NetworkInterfaceDnsSettings.new()
# dns_settings.dns_servers = nil

# nic_object = Azure::ARM::Network::Models::NetworkInterface.new()
# nic_object.dns_settings = dns_settings
# nic_object.ip_configurations = [ip_config]
# nic_object.location = 'WestEurope'
# nic_object.name = 'TestCSRENic2'


# new_nic = client.network_interfaces.create_or_update(rg_name, nic_name, nic_object)


# listofnics = client.network_interfaces.list(rg_name)



# 52.166.248.211
