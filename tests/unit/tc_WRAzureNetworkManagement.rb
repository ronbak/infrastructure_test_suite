#!/usr/bin/env ruby
require 'simplecov'
SimpleCov.start

require 'minitest/reporters'
require 'minitest/autorun'
require_relative '../../lib/WRAzureNetworkManagement'
require_relative '../../lib/WRConfigManager'
MiniTest::Reporters.use! [MiniTest::Reporters::DefaultReporter.new,
                          MiniTest::Reporters::JUnitReporter.new]


class TestWRAzureNetworkManagement <  MiniTest::Test

  def setup()
    @wraznm = WRAzureNetworkManagement.new(environment: 'dev')
    @envs_array = ['dev', 'uat', 'tst', 'ci', 'int', 'ppd', 'nonprd', 'prd', 'core']
  end

  def test_initialize
    assert_instance_of(WRAzureNetworkManagement, @wraznm)
  end
end
