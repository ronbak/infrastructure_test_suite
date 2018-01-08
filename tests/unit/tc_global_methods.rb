#!/usr/bin/env ruby
require 'simplecov'
SimpleCov.start

require 'minitest/reporters'
require 'minitest/autorun'
require_relative '../../lib/global_methods'
require_relative '../../lib/CSRELogger'
require_relative '../../lib/WRAzureCredentials'
MiniTest::Reporters.use! [MiniTest::Reporters::DefaultReporter.new,
                          MiniTest::Reporters::JUnitReporter.new]



class Testglobal_methods <  MiniTest::Test

  def setup()
    @nonprd_envs_array = ['dev', 'uat', 'tst', 'ci', 'int', 'ppd']
    @csrelog = CSRELogger.new('INFO')
  end

  def test_depp_merge
    hash1 = { "key1" => "value1", "key2" => { "nested_key1" => "nested_value1" } }
    hash2 = { "key3" => "value3", "key4" => { "nested_key2" => "nested_value2" } }
    assert_equal({"key1"=>"value1", "key2"=>{"nested_key1"=>"nested_value1"}, "key3"=>"value3", "key4"=>{"nested_key2"=>"nested_value2"}}, hash1.deep_merge(hash2))
    hash3 = { "key1" => "value1", "key2" => { "nested_key2" => "nested_value2" } }
    assert_equal({"key1"=>"value1", "key2"=>{"nested_key1"=>"nested_value1", "nested_key2"=>"nested_value2"}}, hash1.deep_merge(hash3))
    hash4 = { "key1" => "value10", "key3" => { "nested_key2" => "nested_value2" } }
    assert_equal({"key1"=>"value10", "key2"=>{"nested_key1"=>"nested_value1"}, "key3"=>{"nested_key2"=>"nested_value2"}}, hash1.deep_merge(hash4))
    assert_equal({"key1"=>"value1", "key3"=>{"nested_key2"=>"nested_value2"}, "key2"=>{"nested_key1"=>"nested_value1"}}, hash4.deep_merge(hash1))
    hash5 = { "key3" => "value10", "key2" => { "nested_key2" => "nested_value2" } }
    assert_equal({"key1"=>"value1", "key2"=>{"nested_key1"=>"nested_value1", "nested_key2"=>"nested_value2"}, "key3"=>"value10"}, hash1.deep_merge(hash5))
  end

  def test_key
    assert_operator(key().length, :>=, 1675)
  end

  def test_encrypt_decrypt
    clear_text = 'sometext'
    encrypted_text = encrypt(clear_text)
    assert_instance_of(String, encrypt(clear_text))
    refute_equal(clear_text, encrypt(clear_text))
    assert_equal(clear_text, decrypt(encrypt(clear_text)))
  end

  def test_wrmetadata
    assert_instance_of(Hash, wrmetadata())
    assert_instance_of(Hash, wrmetadata()['global'])
  end

  def test_wrmetadata_regex
    resource_types = ["Microsoft.Network/virtualNetworks", "Microsoft.Compute/virtualMachines", "Microsoft.Network/networkSecurityGroups", "Microsoft.Storage/storageAccounts"]
    resource_types.each do |resource_type|
      assert_instance_of(String, wrmetadata_regex(resource_type))
    end
  end

  def test_wrenvironmentdata
    @nonprd_envs_array.each do |environment|
      assert_instance_of(Hash, wrenvironmentdata(environment))
      assert_equal('nonprd', wrenvironmentdata(environment)['name'])
    end
    assert_equal('prd', wrenvironmentdata('prd')['name'])
    assert_equal('core', wrenvironmentdata('core')['name'])
  end

  def test_create_deployment_name
    assert_instance_of(String, create_deployment_name())
    assert_equal('armRubyAutomation', create_deployment_name().split('-')[0])
    assert_equal(true, create_deployment_name().split('-')[-1].length.eql?(12))
  end

  def test_uri?
    assert_equal(false, uri?('sometext'))
    assert_equal(true, uri?('http://mywebsite'))
    assert_equal(true, uri?('https://mywebsite'))
    assert_equal(true, uri?('http://mywebsite.com'))
    assert_equal(true, uri?('https://mywebsite.com'))
  end

  def test_caesar_cipher
    assert_equal("tpnfufyu", caesar_cipher('sometext'))
  end

  def test_convert_git_raw_to_api
    assert_equal('https://api.github.com/repos/Worldremit/csre_documentation/contents/file_path.txt?ref=master', convert_git_raw_to_api('https://raw.githubusercontent.com/Worldremit/csre_documentation/master/file_path.txt'))
    assert_equal('https://api.github.com/repos/Worldremit/csre_documentation/contents/file_path.txt?ref=branch1', convert_git_raw_to_api('https://raw.githubusercontent.com/Worldremit/csre_documentation/branch1/file_path.txt'))
  end

  def test_convert_git_to_api
    assert_equal('https://api.github.com/repos/Worldremit/csre_documentation/contents/file_path.txt?ref=master', convert_git_to_api('https://github.com/Worldremit/csre_documentation/blob/master/file_path.txt'))
    assert_equal('https://api.github.com/repos/Worldremit/csre_documentation/contents/file_path.txt?ref=branch1', convert_git_to_api('https://github.com/Worldremit/csre_documentation/blob/branch1/file_path.txt'))
  end

  def test_write_file
    write_file('test_file.txt', 'sometext')
    assert_equal('sometext', File.read('test_file.txt'))
    File.delete('test_file.txt')
  end

  def test_write_hash_to_disk
    write_hash_to_disk({key: "value1"}, 'test_file.txt')
    assert_equal("{\n  \"key\": \"value1\"\n}", File.read('test_file.txt'))
    File.delete('test_file.txt')
  end

  def test_retrieve_from_internet_anonymous
    assert_equal("test_file\n", retrieve_from_internet_anonymous('https://raw.githubusercontent.com/chudsonwr/testrepo/master/README.md'))
  end

  def test_retrieve_from_github_api
    access_token = WRAzureCredentials.new().get_git_access_token
    raw_data = retrieve_from_github_api('https://raw.githubusercontent.com/Worldremit/csre_documentation/master/README.md', access_token)
    assert_equal("## CSRE Documentation\r\n", raw_data)
  end

  def teardown()
    # ENV['AZURE_CLIENT_SECRET'] = nil
    # ENV['GIT_ACCESS_TOKEN'] = nil
    # ENV['GITLAB_ACCESS_TOKEN'] = nil
    # ENV['AZURE_STORAGE_ACCOUNT_KEY'] = nil
  end
end

