#!/usr/bin/env ruby
require 'simplecov'
SimpleCov.start

require 'minitest/reporters'
require 'minitest/autorun'
require_relative '../../lib/WRAzureCredentials'
MiniTest::Reporters.use! [MiniTest::Reporters::DefaultReporter.new,
                          MiniTest::Reporters::JUnitReporter.new]


$wrazcreds = WRAzureCredentials.new(environment: 'dev')
class TestWRAzureCredentials <  MiniTest::Test

  def setup()
    @envs_array = ['dev', 'uat', 'tst', 'ci', 'int', 'ppd', 'nonprd', 'prd', 'core']
  end

  def test_initialize
    assert_instance_of(WRAzureCredentials, WRAzureCredentials.new(environment: 'dev'))
    assert_instance_of(WRAzureCredentials, WRAzureCredentials.new(environment: 'prd'))
    assert_instance_of(WRAzureCredentials, WRAzureCredentials.new(environment: 'core'))
    assert_instance_of(WRAzureCredentials, WRAzureCredentials.new(environment: 'nonprd'))
  end

  def test_get_client_secret
    ENV['TST_AZURE_CLIENT_SECRET'] = 'somedodgyclientsecret'
    assert_equal('somedodgyclientsecret', $wrazcreds.get_client_secret('TST_AZURE_CLIENT_SECRET'))
  end

  def test_get_git_access_token
    ENV['TST_GIT_ACCESS_TOKEN'] = 'somedodgyclientsecret'
    assert_equal('somedodgyclientsecret', $wrazcreds.get_git_access_token('TST_GIT_ACCESS_TOKEN'))
  end

  def test_get_gitlab_access_token
    ENV['TST_GITLAB_ACCESS_TOKEN'] = 'somedodgyclientsecret'
    assert_equal('somedodgyclientsecret', $wrazcreds.get_gitlab_access_token('TST_GITLAB_ACCESS_TOKEN'))
  end

  def test_get_storage_account_key
    ENV['TST_AZURE_STORAGE_ACCOUNT_KEY'] = 'somedodgyclientsecret'
    assert_equal('somedodgyclientsecret', $wrazcreds.get_storage_account_key('TST_AZURE_STORAGE_ACCOUNT_KEY'))
  end
  
  def test_retrieve_secret()
    $wrazcreds.write_creds_file('mydodgypassword', 'temp_key_file')
    $wrazcreds.retrieve_secret('NOT_A_REAL_ENV_VAR', "#{ENV['HOME']}/.ssh/azure_ruby_key", 'temp_key_file')
    File.delete('temp_key_file')
  end

  def test_determine_client_id()
    @envs_array.each do |env|
      assert_equal('41c29dbb-eaf3-4b0b-9069-24bfb00af65f', $wrazcreds.determine_client_id(env))
    end
  end

  def test_authenticate()
    $wrazcreds.write_creds_file('mydodgypassword', 'temp_key_file')
    assert_instance_of(MsRest::TokenCredentials, $wrazcreds.authenticate)
    File.delete('temp_key_file')
  end

  def teardown()
    # ENV['AZURE_CLIENT_SECRET'] = nil
    # ENV['GIT_ACCESS_TOKEN'] = nil
    # ENV['GITLAB_ACCESS_TOKEN'] = nil
    # ENV['AZURE_STORAGE_ACCOUNT_KEY'] = nil
  end
end
