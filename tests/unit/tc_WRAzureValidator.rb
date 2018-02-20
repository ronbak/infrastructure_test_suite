#!/usr/bin/env ruby
require 'simplecov'
SimpleCov.start

require 'minitest/reporters'
require 'minitest/autorun'
require 'pry-byebug'
require_relative '../../lib/WRAzureValidator'
require_relative '../../lib/WRConfigManager'
require_relative '../../lib/CSRELogger'
MiniTest::Reporters.use! [MiniTest::Reporters::DefaultReporter.new,
                          MiniTest::Reporters::JUnitReporter.new]



class TestWRAzureValidator <  MiniTest::Test

  def setup()
    @environment = 'nonprd'
    @rg_name = 'networking-rg-eurn-nonprd-wr'
    @config = WRConfigManager.new(config: "#{File.dirname(__FILE__)}/../test_data/networking_eurn_master.config.json")
    @output = "#{File.dirname(__FILE__)}/../test_data/validator_output/nonprd_eurn_network.json"
    @wrvdtr = WRAzureValidator.new(config: @config, environment: @environment, rg_name: @rg_name, output: @output)
  end

  def test_initialize
    assert_instance_of(WRAzureValidator, @wrvdtr)
  end

  def test_find_params_file
    result = @wrvdtr.find_params_file(@output)
    assert_instance_of(Hash, result)
    assert_instance_of(Array, result.dig('templates'))
    assert_equal(4, result.dig('templates').count)
    assert_instance_of(String, result.dig('parameters'))
  end

  def test_validate
    assert_instance_of(Hash, @wrvdtr.validate)
  end
end
