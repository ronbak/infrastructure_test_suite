require 'simplecov'
SimpleCov.start

require 'minitest/reporters'
require 'minitest/autorun'
require_relative '../lib/WRDnsTester'
MiniTest::Reporters.use! [MiniTest::Reporters::DefaultReporter.new,
                          MiniTest::Reporters::JUnitReporter.new]

class TestWRDnsTester < MiniTest::Test

	def test_dns_server_is_alive
		dns_servers = ['10.1.10.31', '10.1.10.32']

		dns_servers.each do |dns_server|
			assert_equal(true, WRDnsTester.new(dns_servers: [dns_server], external: true).test_servers)
		end
	end
end