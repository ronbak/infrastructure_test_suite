require 'minitest/reporters'
require 'minitest/autorun'
require_relative '../lib/WRAzureWebServers'
MiniTest::Reporters.use! [MiniTest::Reporters::DefaultReporter.new,
                          MiniTest::Reporters::JUnitReporter.new]

class TestWRAzureWebServers < MiniTest::Test

	def test_servers_up
		environment = 'prod'
		webserver_tester = WRAzureWebServers.new(environment: environment)
		results = webserver_tester.check_wr_web_servers()
		assert_operator results[:up].count, :>=, 2
		assert_operator results[:down].count, :==, 0
	end
end