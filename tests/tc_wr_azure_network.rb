require 'minitest/reporters'
require 'minitest/autorun'
require_relative '../lib/WRAzureNetworkManagement'
MiniTest::Reporters.use! [MiniTest::Reporters::DefaultReporter.new,
                          MiniTest::Reporters::JUnitReporter.new]

class TestWRAzureNetworkManagement < MiniTest::Test

	def test_available_ips
		environment = 'dev'
		client_id = 'f03b94d9-6086-4570-808b-45b4a81af751'
		vnet = 'armtestvnet1'
		resource_group = 'armtestnetwork1'

		network_tester = WRAzureNetworkManagement.new(client_id: client_id, environment: environment)
		results = network_tester.list_available_ips(resource_group: resource_group, vnet: vnet)
		results.each do |subnet, ip_count|
			assert_operator ip_count.to_i, :>=, 10
		end
	end
end