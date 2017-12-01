#!/usr/bin/env ruby
require 'simplecov'
SimpleCov.start

require 'minitest/reporters'
require 'minitest/autorun'
require 'pry-byebug'
require_relative '../../lib/WRSubnetInjector'
require_relative '../../lib/CSRELogger'
MiniTest::Reporters.use! [MiniTest::Reporters::DefaultReporter.new,
                          MiniTest::Reporters::JUnitReporter.new]



class TestWRSubnetInjector <  MiniTest::Test

  def setup()
    @vnet_template = JSON.parse(File.read("#{File.dirname(__FILE__)}/../test_data/vnet.template.json"))
    @parameters = JSON.parse(File.read("#{File.dirname(__FILE__)}/../test_data/network_params.test.json"))
    @wrsubinj = WRSubnetInjector.new(@vnet_template, 
      'nonprd', 
      @parameters)
    @environment = 'nonprd'
  end

  def test_initialize
    assert_instance_of(WRSubnetInjector, @wrsubinj)
  end

  def test_build_subnet_hash()
    landscapes = ['dev', 'tst', 'uat', 'ci', 'int', 'ppd']
    subnets = ['private', 'privatepartner', 'publicclient', 'publicpartner']
    route_table = @vnet_template['resources'].find { |resource| resource['type'] == 'Microsoft.Network/routeTables' }
    route_table_name = route_table['name'].gsub('[', '').gsub(']', '')
    landscapes.each do |landscape|
      subnets.each do |subnet|
        subnet_hash = @wrsubinj.build_subnet_hash(landscape, subnet, '10.24.16.0/23', route_table_name)
        assert_equal("#{landscape}-#{subnet}", subnet_hash.dig('name'))
        assert_equal('10.24.16.0/23', subnet_hash.dig('properties', 'addressPrefix'))
        assert_equal("[resourceId('Microsoft.Network/networkSecurityGroups', 'nsg01-#{landscape}-#{@parameters['location_tag']['value']}-#{subnet}')]", subnet_hash.dig('properties', 'networkSecurityGroup', 'id'))
        assert_equal("[resourceId('Microsoft.Network/routeTables', concat(parameters('location_tag'), '-', parameters('environment'), '-routetable-01'))]", subnet_hash.dig('properties', 'routeTable', 'id'))
      end
    end
    subnet_hash = @wrsubinj.build_subnet_hash('gateway', 'external', '10.24.16.0/23', route_table_name)
    assert_equal("nonprd-external", subnet_hash.dig('name'))
    assert_equal("[resourceId('Microsoft.Network/networkSecurityGroups', 'nsg01-nonprd-eurw-external')]", subnet_hash.dig('properties', 'networkSecurityGroup', 'id'))
    assert_nil(subnet_hash.dig('properties', 'routeTable'))

    subnet_hash = @wrsubinj.build_subnet_hash('gateway', 'GatewaySubnet', '10.24.16.0/23', route_table_name)
    assert_equal("GatewaySubnet", subnet_hash.dig('name'))
    assert_equal('10.24.16.0/23', subnet_hash.dig('properties', 'addressPrefix'))
    assert_nil(subnet_hash.dig('properties', 'routeTable'))
    assert_nil(subnet_hash.dig('properties', 'networkSecurityGroup'))

    @environment = 'core'
    subnet_hash = @wrsubinj.build_subnet_hash('core', 'aadds', '10.24.16.0/23', route_table_name)
    assert_equal("core-aadds", subnet_hash.dig('name'))
    assert_equal('10.24.16.0/23', subnet_hash.dig('properties', 'addressPrefix'))
    assert_equal("[resourceId('Microsoft.Network/routeTables', concat(parameters('location_tag'), '-', parameters('environment'), '-routetable-01'))]", subnet_hash.dig('properties', 'routeTable', 'id'))
    assert_nil(subnet_hash.dig('properties', 'networkSecurityGroup'))
  end

  def test_add_subnets_to_existing_template()
    vnet = @wrsubinj.add_subnets_to_existing_template(@vnet_template)
    assert_equal(9, vnet['resources'].find { |resource| resource['name'] == "[parameters('vNetName')]" }.dig('properties', 'subnets').count)
    assert_equal('GatewaySubnet', vnet['resources'].find { |resource| resource['name'] == "[parameters('vNetName')]" }.dig('properties', 'subnets')[0]['name'])
    landscapes = ['dev', 'tst']
    subnets = ['private', 'privatepartner', 'publicclient', 'publicpartner']
    landscapes.each do |landscape|
      subnets.each do |subnet|
        assert_instance_of(Hash, vnet['resources'].find { |resource| resource['name'] == "[parameters('vNetName')]" }.dig('properties', 'subnets').find { |subnet_hash| subnet_hash['name'] == "#{landscape}-#{subnet}" })
      end
    end
  end
end

