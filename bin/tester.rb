#!/usr/bin/env ruby
require 'optparse'
require 'ostruct'
require 'json'
require_relative '../lib/WRAzureNetworkManagement'

@options = OpenStruct.new
@options[:location] = 'WestEurope'

def parse_args(args)
  opt_parser = OptionParser.new do |opts|
    opts.banner = 'Usage: tester.rb [options]'
    opts.on('-c ClientId', '--clientid ClientId', 'ClientId to run tests with - Required') do |clientid|
      @options[:clientid] = clientid
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
  end
  opt_parser.parse!(args)

  if @options[:clientid].nil? || @options[:environment].nil?
    puts 'you\'re missing the --clientid or --environment option. You must specify --clientid and --environment'
    exit
  end
  # raise OptionParser::MissingArgument if @options[:cname].nil?
end

parse_args(ARGV)

clientid = @options.clientid
environment = @options.environment
vnet = @options.vnet
resource_group = @options.resource_group


# test network
if resource_group && vnet
  net_tester = WRAzureNetworkManagement.new(client_id: clientid, environment: environment)
  subnet_status = net_tester.list_available_ips(resource_group: resource_group, vnet: vnet)
  puts subnet_status
end