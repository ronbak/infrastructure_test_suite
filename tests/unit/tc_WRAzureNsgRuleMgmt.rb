#!/usr/bin/env ruby
require 'simplecov'
SimpleCov.start

require 'minitest/reporters'
require 'minitest/autorun'
require_relative '../../lib/WRAzureNsgRulesMgmt'
require_relative '../../lib/CSRELogger'
MiniTest::Reporters.use! [MiniTest::Reporters::DefaultReporter.new,
                          MiniTest::Reporters::JUnitReporter.new]


#$config = WRConfigManager.new(config: 'https://raw.githubusercontent.com/Worldremit/arm_templates/master/networks/configs/networking_master.config.json').config
$templates_array = "#{File.dirname(__FILE__)}/../test_data/rules/"
$wrazrm = WRAzureNsgRulesMgmt.new(File.read("#{File.dirname(__FILE__)}/../test_data/network_params.test.json"), $templates_array, CSRELogger.new('INFO', 'STDOUT'))
$envs_array = ['dev', 'uat', 'tst', 'ci', 'int', 'ppd', 'nonprd', 'prd', 'core']

class TestWRAzureNsgRulesMgmt <  MiniTest::Test

  def setup()
  end

  def test_initialize
    assert_instance_of(WRAzureNsgRulesMgmt, $wrazrm)
  end

  def test_process_rules
    assert_equal(JSON.parse(File.read("#{File.dirname(__FILE__)}/../test_data/rules_resources.json")), $wrazrm.process_rules)
  end

  def test_retrieve_resources
    obj_to_test = $wrazrm.retrieve_resources($templates_array)
    assert_instance_of(Array, obj_to_test)
    assert_equal(2, obj_to_test.count)
    assert_equal(JSON.parse(File.read("#{File.dirname(__FILE__)}/../test_data/rules_base-resources.json")), obj_to_test)
  end

  def test_list_template_files
    assert_instance_of(Array, $wrazrm.list_template_files(['this is an array']))
    assert_equal(['this is an array'], $wrazrm.list_template_files(['this is an array']))
    assert_instance_of(Array, $wrazrm.list_template_files("#{File.dirname(__FILE__)}/../test_data/rules_resources.json"))
    assert_equal(["#{File.dirname(__FILE__)}/../test_data/rules_resources.json"], $wrazrm.list_template_files("#{File.dirname(__FILE__)}/../test_data/rules_resources.json"))
    assert_instance_of(Array, $wrazrm.list_template_files("#{File.dirname(__FILE__)}/../test_data/rules"))
    assert_instance_of(Array, $wrazrm.list_template_files("#{File.dirname(__FILE__)}/../test_data/rules/"))
    assert_equal(["#{File.dirname(__FILE__)}/../test_data/rules/nsg_rules_private.json", "#{File.dirname(__FILE__)}/../test_data/rules/nsg_rules_publicclient.json"], $wrazrm.list_template_files("#{File.dirname(__FILE__)}/../test_data/rules"))
    assert_equal(["#{File.dirname(__FILE__)}/../test_data/rules/nsg_rules_private.json", "#{File.dirname(__FILE__)}/../test_data/rules/nsg_rules_publicclient.json"], $wrazrm.list_template_files("#{File.dirname(__FILE__)}/../test_data/rules/"))
    assert_instance_of(Array, $wrazrm.list_template_files("../folder/file1.json ../folder/file2.json"))
    assert_equal(["../folder/file1.json", "../folder/file2.json"], $wrazrm.list_template_files("../folder/file1.json ../folder/file2.json"))
  end

  def test_verify_resources_params
    resources = [{"properties"=>
      {"sourceAddressPrefix"=>"213.57.32.1/32",
        "destinationAddressPrefix"=>"private",
        "direction"=>"Inbound"}
        },{"properties"=>
      {"sourceAddressPrefix"=>"privatepartner",
        "destinationAddressPrefix"=>"publicclient",
        "direction"=>"Inbound"}}]
    assert_equal(resources, $wrazrm.verify_resources_params(resources))
  end
    
end


