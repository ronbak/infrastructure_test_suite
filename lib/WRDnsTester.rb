require 'resolv'

class WRDnsTester

	def initialize(dns_servers: nil, search_domain: 'worldremit.ukfast', external: false)
		log_level = 'INFO'
    log_level = ENV['CSRE_LOG_LEVEL'] unless ENV['CSRE_LOG_LEVEL'].nil?
		@csrelog = CSRELogger.new(log_level, 'STDOUT')
		@dns_servers = dns_servers
		@search_domain = if ENV['DNS_SEARCH_DOMAIN'].nil?
			'worldremit.ukfast'
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
			external = true
			if @external
				external = false
				@csrelog.info('Testing external domain lookup')
				begin
					z = x.getaddress('www.google.com')
					if z
						external = true
					end
				rescue
				end
			end
			return true if dcs.count > 1 && external == true
		rescue
			return false
		end
	end

end
