#!/usr/bin/env ruby
require 'optparse'
require 'ostruct'
require 'json'
require_relative '../lib/WRAzureNetworkManagement'
require_relative '../lib/WRAzureWebServers'
require_relative '../lib/CSRELogger'

@options = OpenStruct.new
@options[:location] = 'WestEurope'

def parse_args(args)
  opt_parser = OptionParser.new do |opts|
    opts.banner = 'Usage: tester.rb [options]'
    opts.on('-c client_name', '--client_name ClientName', 'The Servie Principal name in Azure AD - Required') do |client_name|
      @options[:client_name] = client_name
    end
    opts.on('-e Environment', '--environment Environment', 'Environment you are testing, i.e. dev, prod etc etc') do |environment|
      @options[:environment] = environment
    end
    opts.on('-r ResourceGroup', '--resourcegroup Environment', 'Environment you are testing, i.e. dev, prod etc etc') do |resource_group|
      @options[:resource_group] = resource_group
    end
    opts.on('-v VNet', '--vnet VNet', 'VNet you are testin') do |vnet|
      @options[:vnet] = vnet
    end
    opts.on('-s System', '--system System', 'The system are you testing') do |system|
      @options[:system] = system
    end
      opts.on('-t test', '--test Test', 'The test you would like to perform') do |test|
      @options[:test] = test
    end
  end
  opt_parser.parse!(args)

  # if @options[:client_name].nil? || @options[:environment].nil?
  #   puts 'you\'re missing the --client_name or --environment option. You must specify --client_name and --environment'
  #   exit
  # end
  # raise OptionParser::MissingArgument if @options[:cname].nil?
end

parse_args(ARGV)

client_name = @options.client_name
environment = @options.environment
vnet = @options.vnet
resource_group = @options.resource_group

log_level = 'INFO'
log_level = ENV['CSRE_LOG_LEVEL'] unless ENV['CSRE_LOG_LEVEL'].nil?
@csrelog = CSRELogger.new(log_level, 'STDOUT')

# test network
if resource_group && vnet
  net_tester = WRAzureNetworkManagement.new(client_name: client_name, environment: environment)
  subnet_status = net_tester.list_available_ips(resource_group: resource_group, vnet: vnet)
  puts subnet_status
end

case @options.system
when 'web_servers'
  web_tester = WRAzureWebServers.new(client_name: client_name, environment: environment)
  case @options.test
  when 'get_live_cluster'
    @csrelog.info("The live cluster is: #{web_tester.get_live_colour()}")
  when 'check_wr_web_servers'
    @csrelog.info("The live cluster status is: #{web_tester.check_wr_web_servers()}")
  end
end
