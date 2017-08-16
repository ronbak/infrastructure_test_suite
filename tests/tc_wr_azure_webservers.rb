require 'minitest/reporters'
require 'minitest/autorun'
require_relative '../lib/WRAzureWebServers'
MiniTest::Reporters.use! [MiniTest::Reporters::DefaultReporter.new,
                          MiniTest::Reporters::JUnitReporter.new]

class TestWRAzureWebServers < MiniTest::Test

	def test_servers_up
		environment = 'dev'
		client_name = 'armTemplateAutomation'
		ENV['CSRE_LOG_LEVEL'] = 'DEBUG'
		webserver_tester = WRAzureWebServers.new(client_name: client_name, environment: environment)
		results = webserver_tester.check_wr_web_server_cluster('blue')
		assert_operator results[:up].count, :>=, 1
		assert_operator results[:down].count, :==, 0
	end
end