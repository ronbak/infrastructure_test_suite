#!/usr/bin/env ruby
require 'simplecov'
SimpleCov.start

require 'minitest/reporters'
require 'minitest/autorun'
require_relative '../../lib/WRAzureTemplateManagement'
require_relative '../../lib/CSRELogger'
MiniTest::Reporters.use! [MiniTest::Reporters::DefaultReporter.new,
                          MiniTest::Reporters::JUnitReporter.new]

$envs_array = ['dev', 'uat', 'tst', 'ci', 'int', 'ppd', 'nonprd', 'prd', 'core']
$wraztm = WRAzureTemplateManagement.new(JSON.parse(File.read("#{File.dirname(__FILE__)}/../test_data/linked_templates_test.json")), 'nonprd', "#{File.dirname(__FILE__)}/../test_data/rules/", JSON.parse(File.read("#{File.dirname(__FILE__)}/../test_data/network_params.test.json")), CSRELogger.new('INFO', 'STDOUT'))
$master_template = JSON.parse(File.read("#{File.dirname(__FILE__)}/../test_data/linked_templates_test.json"))
$rules_template = "#{File.dirname(__FILE__)}/../test_data/rules/"
$parameters = JSON.parse(File.read("#{File.dirname(__FILE__)}/../test_data/network_params.test.json"))

class TestWRAzureTemplateManagement <  MiniTest::Test

  def setup()
  end

  def test_initialize
    assert_instance_of(WRAzureTemplateManagement, $wraztm)
  end

  def test_build_templates_list
    assert_instance_of(Array, $wraztm.build_templates_list($master_template))
    assert_equal(1, $wraztm.build_templates_list($master_template).count)
    assert_equal(["https://raw.githubusercontent.com/Worldremit/arm_templates/master/networks/nsgs.json"], $wraztm.build_templates_list($master_template))
  end

  def test_inject_rules_to_template
    resource = $master_template['resources'][0]
    template_url = resource['properties'].dig('templateLink', 'uri')
    raw_template = { resource['properties']['templateLink']['uri'] => JSON.pretty_generate(WRConfigManager.new(config: template_url).config) }
    assert_equal(JSON.parse(File.read("#{File.dirname(__FILE__)}/../test_data/inject_rules_template.json")), $wraztm.inject_rules_to_template($rules_template, raw_template))
  end

  def test_create_sas_url
    assert_equal("https://awcsrenonprd01.blob.core.windows.net/templates/file1.txt?se=2099-01-01T00%3A00%3A00Z&sig=OwzBMDA2HTv53dNu6Am9QP0VgdSXgNzo330MoSFwANM%3D&sp=r&sr=b&st=2017-01-01T00%3A00%3A00Z", $wraztm.create_sas_url(path: 'templates/file1.txt', start: Date.parse("2017-01-01").to_datetime.to_time.utc.iso8601, expiry: Date.parse("2099-01-01").to_datetime.to_time.utc.iso8601))
  end
end

