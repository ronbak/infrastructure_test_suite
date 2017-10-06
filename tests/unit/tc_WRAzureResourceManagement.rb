#!/usr/bin/env ruby
require 'simplecov'
SimpleCov.start

require 'minitest/reporters'
require 'minitest/autorun'
require_relative '../../lib/WRAzureResourceManagement'
require_relative '../../lib/CSRELogger'
MiniTest::Reporters.use! [MiniTest::Reporters::DefaultReporter.new,
                          MiniTest::Reporters::JUnitReporter.new]

$envs_array = ['dev', 'uat', 'tst', 'ci', 'int', 'ppd', 'nonprd', 'prd', 'core']
$wrazrm = WRAzureResourceManagement.new(environment: 'dev', landscape: 'nonprd')

class TestWRAzureResourceManagement <  MiniTest::Test

  def setup()
    @rg_name = 'zzzz-test-rg-nonprd-wr'
    @tags = {}
    @tags['Name'] = 'zzzz-test-rg'
    @tags['environment'] = 'nonprd'
    @tags['Location'] = 'WestEurope'
    @tags['RunModel'] = 'm-f'
  end

  def test_initialize
    assert_instance_of(WRAzureResourceManagement, $wrazrm)
  end

  def test_create_resource_group
    assert_equal('Succeeded', $wrazrm.create_resource_group('WestEurope', @rg_name, @tags))
    obj = $wrazrm.get_resource_group(@rg_name)
    assert_instance_of(Azure::ARM::Resources::Models::ResourceGroup, obj)
    assert_equal(@rg_name, obj.name)
    assert_equal("/subscriptions/9c255757-a7c8-4c88-8476-0d7bf926dd6a/resourceGroups/#{@rg_name}", obj.id)
    assert_equal(@tags, obj.tags)
    assert_nil($wrazrm.delete_resource_group(@rg_name))
  end

  def test_list_resource_groups
    obj = $wrazrm.list_resource_groups
    assert_instance_of(Array, obj)
    obj.each do |rg_name|
      assert_instance_of(String, rg_name)
    end
  end
end
