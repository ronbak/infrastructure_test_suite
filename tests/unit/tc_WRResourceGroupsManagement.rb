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
    @rg_name = 'mytestresourcegroup'
    @config = WRConfigManager.new(config: "#{File.dirname(__FILE__)}/../test_data/networking_eurn_core.config.json")
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
    assert_equal('./../test_data/validator_output/nonprd_eurn_network.parameters.json', result.dig('parameters'))
  end

  def test_create_azure_au_client
    assert_instance_of(Azure::ARM::Authorization::AuthorizationManagementClient, @wrrgm.create_azure_au_client(@environment))
  end

  def test_create_azure_rm_client
    assert_instance_of(Azure::ARM::Resources::ResourceManagementClient, @wrrgm.create_azure_rm_client(@environment))
  end

  def test_find_assignment
      assert_nil(@wrrgm.find_assignment(@au_client, @fake_scope, @role_definition_id, @group_id))
      role_assignment = @wrrgm.find_assignment(@au_client, @real_scope, @role_definition_id, @group_id)
      assert_instance_of(Azure::ARM::Authorization::Models::RoleAssignment, role_assignment)
      assert_equal("/subscriptions/9c255757-a7c8-4c88-8476-0d7bf926dd6a/resourceGroups/sql-rg-dev-wr/providers/Microsoft.Authorization/roleAssignments/3c562ebb-b6d1-4b73-b1d2-2c4628320a6c", role_assignment.id)
  end

  def test_create_tags_hash
    assert_equal({"name"=>"service21-rg-nonprd-wr",
      "Location"=>"NorthEurope",
      "Environment"=>"dev",
      "RunModel"=>"9-5",
      "environment"=>"nonprd",
      "location"=>"WestEurope"}, @wrrgm.create_tags_hash(@tags, 'nonprd'))
    assert_equal({"name"=>"service21-rg-prd-wr",
      "Location"=>"NorthEurope",
      "Environment"=>"dev",
      "RunModel"=>"247",
      "environment"=>"prd",
      "location"=>"WestEurope"}, @wrrgm.create_tags_hash(@tags, 'prd'))
  end
end

