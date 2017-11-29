#!/usr/bin/env ruby
require 'simplecov'
SimpleCov.start

require 'minitest/reporters'
require 'minitest/autorun'
require_relative '../../lib/WRAzureStorageManagement'
require_relative '../../lib/CSRELogger'
MiniTest::Reporters.use! [MiniTest::Reporters::DefaultReporter.new,
                          MiniTest::Reporters::JUnitReporter.new]

$envs_array = ['dev', 'uat', 'tst', 'ci', 'int', 'ppd', 'nonprd', 'prd', 'core']
$wrazsm = WRAzureStorageManagement.new(environment: 'dev', rg_name: 'csre_storage-rg-nonprd-wr', container: 'testcontainerignore')

class TestWRAzureStorageManagement <  MiniTest::Test

  def setup()
  end

  def test_initialize
    assert_instance_of(WRAzureStorageManagement, $wrazsm)
  end

  def test_container_methods
    # create container
    obj = $wrazsm.create_container()
    assert_instance_of(Azure::Blob::Container, obj)
    assert_equal('testcontainerignore', obj.name)
    assert_nil(obj.public_access_level)
    # get container
    obj = $wrazsm.get_container()
    assert_equal('testcontainerignore', obj.name)
    assert_nil(obj.public_access_level)
    # upload a file to container
    obj = $wrazsm.upload_file_to_storage('some random text', 'test_file')
    assert_instance_of(Azure::Blob::Blob, obj)
    assert_equal('test_file', obj.name)
    assert_equal('B2caA4wOtDcj1CFpOwc8Ow==', obj.properties[:content_md5])
    # delete file / blob
    assert_nil($wrazsm.delete_blob('testcontainerignore', 'test_file'))
    # delete container
    assert_nil($wrazsm.delete_container('testcontainerignore'))
  end

  def teardown()
    # $wrazsm.delete_blob('testcontainerignore', 'test_file')
    # $wrazsm.delete_container('testcontainerignore')
  end
  
end
