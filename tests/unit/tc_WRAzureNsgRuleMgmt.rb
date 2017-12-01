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
$template = "#{File.dirname(__FILE__)}/../test_data/nsg_template.json"
$pre_processed_template = "#{File.dirname(__FILE__)}/../test_data/nsg_template_pre.json"
$wrazrulesm = WRAzureNsgRulesMgmt.new(File.read("#{File.dirname(__FILE__)}/../test_data/network_params.test.json"), $templates_array, $template, CSRELogger.new('INFO', 'STDOUT'))
$envs_array = ['dev', 'uat', 'tst', 'ci', 'int', 'ppd', 'nonprd', 'prd', 'core']

class TestWRAzureNsgRulesMgmt <  MiniTest::Test

  def setup()
  end

  def test_initialize
    assert_instance_of(WRAzureNsgRulesMgmt, $wrazrulesm)
  end

  def test_process_rules
    #assert_equal(JSON.parse(File.read("#{File.dirname(__FILE__)}/../test_data/rules_resources.json")), $wrazrulesm.process_rules)
  end

  def test_retrieve_resources
    obj_to_test = $wrazrulesm.retrieve_resources($templates_array)
    assert_instance_of(Array, obj_to_test)
    assert_equal(2, obj_to_test.count)
    assert_equal(JSON.parse(File.read("#{File.dirname(__FILE__)}/../test_data/rules_base-resources.json")), obj_to_test)
  end

  def test_list_template_files
    assert_instance_of(Array, $wrazrulesm.list_template_files(['this is an array']))
    assert_equal(['this is an array'], $wrazrulesm.list_template_files(['this is an array']))
    assert_instance_of(Array, $wrazrulesm.list_template_files("#{File.dirname(__FILE__)}/../test_data/rules_resources.json"))
    assert_equal(["#{File.dirname(__FILE__)}/../test_data/rules_resources.json"], $wrazrulesm.list_template_files("#{File.dirname(__FILE__)}/../test_data/rules_resources.json"))
    assert_instance_of(Array, $wrazrulesm.list_template_files("#{File.dirname(__FILE__)}/../test_data/rules"))
    assert_instance_of(Array, $wrazrulesm.list_template_files("#{File.dirname(__FILE__)}/../test_data/rules/"))
    assert_equal(["#{File.dirname(__FILE__)}/../test_data/rules/nsg_rules_private.json", "#{File.dirname(__FILE__)}/../test_data/rules/nsg_rules_publicclient.json"], $wrazrulesm.list_template_files("#{File.dirname(__FILE__)}/../test_data/rules"))
    assert_equal(["#{File.dirname(__FILE__)}/../test_data/rules/nsg_rules_private.json", "#{File.dirname(__FILE__)}/../test_data/rules/nsg_rules_publicclient.json"], $wrazrulesm.list_template_files("#{File.dirname(__FILE__)}/../test_data/rules/"))
    assert_instance_of(Array, $wrazrulesm.list_template_files("../folder/file1.json ../folder/file2.json"))
    assert_equal(["../folder/file1.json", "../folder/file2.json"], $wrazrulesm.list_template_files("../folder/file1.json ../folder/file2.json"))
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
    assert_equal(resources, $wrazrulesm.verify_resources_params(resources))
  end

  def test_core_added_subnets
    local_templates_array = "#{File.dirname(__FILE__)}/../test_data/rules_core/"
    core_wrazrm = WRAzureNsgRulesMgmt.new(File.read("#{File.dirname(__FILE__)}/../test_data/network_core_params.test.json"), local_templates_array, $template, CSRELogger.new('INFO', 'STDOUT'))
    #assert_equal(JSON.parse(File.read("#{File.dirname(__FILE__)}/../test_data/rules_core_resources.json")), core_wrazrm.process_rules)
  end

  def test_clean_condition
    comparison, container, element = $wrazrulesm.clean_condition("[contains(parent_resource/name, '-int-')]")
    assert_instance_of(Array, $wrazrulesm.clean_condition("[contains(parent_resource/name, '-int-')]"))
    assert_equal("contains", comparison)
    assert_equal("parent_resource/name", container)
    assert_equal("-int-", element)
    comparison, container, element = $wrazrulesm.clean_condition("[equal(parent_resource/name, '-int-')]")
    assert_equal("equal", comparison)
    comparison, container, element = $wrazrulesm.clean_condition("[not_equal(parent_resource/name, '-int-')]")
    assert_equal("not_equal", comparison)
  end

  def test_resolve_comparison_container
    assert_equal("nsg01-dev-eurw-privatepartner", $wrazrulesm.resolve_comparison_container(JSON.parse(File.read($pre_processed_template)), 'parent_resource/name'))
    assert_equal("Microsoft.Network/networkSecurityGroups", $wrazrulesm.resolve_comparison_container(JSON.parse(File.read($pre_processed_template)), 'parent_resource/type'))
  end

  def test_condition_met?
    nsg = JSON.parse(File.read($pre_processed_template))
    assert_equal(false, $wrazrulesm.condition_met?(nsg, { "condition" => "[contains(parent_resource/name, '-int-')]" }))
    assert_equal(true, $wrazrulesm.condition_met?(nsg, { "condition" => "[contains(parent_resource/name, '-dev-')]" }))
    assert_equal(false, $wrazrulesm.condition_met?(nsg, { "condition" => "[equal(parent_resource/name, 'nsg01-dev-eurw-privatepartner1')]" }))
    assert_equal(true, $wrazrulesm.condition_met?(nsg, { "condition" => "[equal(parent_resource/name, 'nsg01-dev-eurw-privatepartner')]" }))
    assert_equal(false, $wrazrulesm.condition_met?(nsg, { "condition" => "[not_equal(parent_resource/name, 'nsg01-dev-eurw-privatepartner')]" }))
    assert_equal(true, $wrazrulesm.condition_met?(nsg, { "condition" => "[not_equal(parent_resource/name, 'nsg01-dev-eurw-privatepartner1')]" }))
  end
    
end


