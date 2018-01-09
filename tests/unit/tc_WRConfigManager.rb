#!/usr/bin/env ruby
require 'simplecov'
SimpleCov.start

require 'minitest/reporters'
require 'minitest/autorun'
require 'pry-byebug'
require_relative '../../lib/WRConfigManager'
require_relative '../../lib/WRAzureCredentials'
require_relative '../../lib/CSRELogger'
MiniTest::Reporters.use! [MiniTest::Reporters::DefaultReporter.new,
                          MiniTest::Reporters::JUnitReporter.new]

class TestWRConfigManagement <  MiniTest::Test

  def setup()

  end

  def test_initialize
    assert_instance_of(WRConfigManager, WRConfigManager.new(config: {}))
  end

  def test_configs
    configs_array = [
      'https://raw.githubusercontent.com/Worldremit/arm_templates/master/networks/configs/networking_master.config.json',
      'https://github.com/Worldremit/arm_templates/blob/master/networks/configs/networking_master.config.json',
      {},
      "#{File.dirname(__FILE__)}/../test_data/inject_rules_template.json",
      File.read("#{File.dirname(__FILE__)}/../test_data/inject_rules_template.json")
    ]
    configs_array.each do |config|
      obj = WRConfigManager.new(config: config)
      assert_instance_of(WRConfigManager, obj)
      assert_instance_of(Hash, obj.config)
    end
  end

  def test_accessors
    obj = WRConfigManager.new(config: JSON.parse(File.read("#{File.dirname(__FILE__)}/../test_data/networking_master.config.json")))
    assert_instance_of(Hash, obj.environments)
    assert_instance_of(Hash, obj.template)
    assert_instance_of(Array, obj.rules)
    assert_instance_of(Hash, obj.config)
    assert_nil(obj.tags('env'))
    assert_nil(obj.client_name)
    assert_instance_of(String, obj.rg_name('nonprd'))
    assert_instance_of(Hash, obj.parameters)
  end
end

