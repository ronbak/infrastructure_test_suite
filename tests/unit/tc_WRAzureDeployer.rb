#!/usr/bin/env ruby
require 'simplecov'
SimpleCov.start

require 'minitest/reporters'
require 'minitest/autorun'
require_relative '../../lib/WRAzureDeployer'
require_relative '../../lib/WRConfigManager'
MiniTest::Reporters.use! [MiniTest::Reporters::DefaultReporter.new,
                          MiniTest::Reporters::JUnitReporter.new]


class TestWRAzureDeployer <  MiniTest::Test

  def setup()
    config_manager = WRConfigManager.new(config: "#{File.dirname(__FILE__)}/../test_data/test.config.json")
    @wrazdep = WRAzureDeployer.new(action: 'output', environment: 'dev', config_manager: config_manager, output: 'temptest.json')
    @envs_array = ['dev', 'uat', 'tst', 'ci', 'int', 'ppd', 'nonprd', 'prd', 'core']
  end

  def test_initialize
    assert_instance_of(WRAzureDeployer, @wrazdep)
  end

  def test_process_deployment
    @wrazdep.process_deployment()
    assert_equal(File.read("#{File.dirname(__FILE__)}/../test_data/temptest.parameters.json"), File.read('temptest.parameters.json'))
    File.delete('temptest.parameters.json')
    File.delete('temptest.json')
  end

  def test_run_deployment
    @wrazdep.run_deployment(@wrazdep.template)
    assert_equal(File.read("#{File.dirname(__FILE__)}/../test_data/temptest.parameters.json"), File.read('temptest.parameters.json'))
    File.delete('temptest.parameters.json')
    File.delete('temptest.json')
  end

  def test_build_deployment_object
    deployment = @wrazdep.build_deployment_object(@wrazdep.template)
    assert_instance_of(Azure::ARM::Resources::Models::Deployment, deployment)
    assert_instance_of(Azure::ARM::Resources::Models::DeploymentProperties, deployment.properties)
    assert_equal('Incremental', deployment.properties.mode)
    assert_equal(JSON.parse(File.read("#{File.dirname(__FILE__)}/../test_data/temptest.parameters.json"))['parameters'], deployment.properties.parameters)
    assert_equal(JSON.parse(File.read("#{File.dirname(__FILE__)}/../test_data/test.template.json")), deployment.properties.template)
  end

  def test_add_environment_values
    assert_equal(JSON.parse(File.read("#{File.dirname(__FILE__)}/../test_data/temptest.parameters.json"))['parameters'], @wrazdep.add_environment_values())
  end
end
