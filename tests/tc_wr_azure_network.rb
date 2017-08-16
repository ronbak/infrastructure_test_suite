require 'minitest/reporters'
require 'minitest/autorun'
require_relative '../lib/WRAzureNetworkManagement'
MiniTest::Reporters.use! [MiniTest::Reporters::DefaultReporter.new,
                          MiniTest::Reporters::JUnitReporter.new]

class TestWRAzureNetworkManagement < MiniTest::Test

	def test_available_ips
		environment = 'dev'
		#client_name = 'armTemplateAutomation'
		vnet = 'armtestvnet1'
		resource_group = 'armtestnetwork1'

		network_tester = WRAzureNetworkManagement.new(client_name: client_name, environment: environment)
		results = network_tester.list_available_ips(resource_group: resource_group, vnet: vnet)
		results.each do |subnet, ip_count|
			assert_operator ip_count.to_i, :>=, 10
		end
	end
end
