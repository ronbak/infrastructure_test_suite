require_relative 'global_methods'
require_relative 'WRAzureCredentials'
require_relative 'CSRELogger'
require 'azure_mgmt_network'

class WRAzureNetworkManagement

	def initialize(environment: nil, client_name: nil)
		log_level = 'INFO'
    log_level = ENV['CSRE_LOG_LEVEL'] unless ENV['CSRE_LOG_LEVEL'].nil?		
		@csrelog = CSRELogger.new(log_level, 'STDOUT')
		@environment = wrenvironmentdata(environment)['name']
		options = {environment: @environment, client_name: client_name}
		@credentials = WRAzureCredentials.new(options).authenticate()
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

	def list_available_ips(resource_group: nil, vnet: nil, subnet: nil)
		subnets = @client.subnets.list(resource_group, vnet)
		if subnet
			subnets = subnets.select { |net| net.name == subnet }
		end
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
					@csrelog.debug("checking IP: #{ip}")
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
			@csrelog.info("there are: #{available_ips.count} available IP addresses in #{subnet.name}")
	  end
	  return vnet_ip_availability
  end

end
