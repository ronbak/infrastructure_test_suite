require 'resolv'

class WRDnsTester

	def initialize(dns_servers: nil, external: false)
		@dns_servers = dns_servers
		@search_domain = if ENV['DNS_SEARCH_DOMAIN'].nil?
			'wrhammersmith.worldremit.com'
		else
			ENV['DNS_SEARCH_DOMAIN']
		end
		@external = external
	end

	def test_servers()
		x = Resolv::DNS.new(nameserver: @dns_servers, search: @search_domain , ndots: 1, timeouts: 1)
		x.timeouts = 1
		begin
			dcs = x.getaddresses('')
			if @external
				puts 'Testing external domain lookup'
				x.getaddress('www.google.com')
			end
			return true if dcs.count > 1
		rescue
			return false
		end
	end

end
