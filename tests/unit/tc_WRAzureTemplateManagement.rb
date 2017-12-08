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
    #assert_equal(JSON.parse(File.read("#{File.dirname(__FILE__)}/../test_data/inject_rules_template.json")), $wraztm.inject_rules_to_template($rules_template, raw_template))
  end

  def test_create_sas_url
    access_policy = wrmetadata().dig('nonprd', 'storage_account', 'container_access_policy')
    assert_equal("https://awcsrenonprd01.blob.core.windows.net/templates/file1.txt?si=saslinkedtemplates&sig=F61pscKd4P7CK0eDxXESNBhRBRM%2FSajQOkt5o%2F5ggAs%3D&sr=b&sv=2015-04-05", 
      $wraztm.create_sas_url(path: 'templates/file1.txt', identifier: access_policy))
  end

  def test_sanitize_template_params()    
    template = {"parameters"=>
        {"vNetName"=>{"type"=>"string"},
        "vNet"=>{"type"=>"object"},
        "subnets_array"=>{"type"=>"array"},
        "sharedKey"=>{"type"=>"securestring"},
        "create_peers"=>{"type"=>"bool"}},
      "resources"=>[{"properties"=>{"parameters"=>{}, "templateLink"=>{"uri"=>"./arm_templates/networks/nsgs.json"}}}]}

    result = {"parameters"=>
      {"vNetName"=>{"type"=>"string", "defaultValue"=>""},
       "vNet"=>{"type"=>"object", "defaultValue"=>{}},
      "subnets_array"=>{"type"=>"array", "defaultValue"=>[]},
      "sharedKey"=>{"type"=>"securestring", "defaultValue"=>""},
      "create_peers"=>{"type"=>"bool", "defaultValue"=>false}},
    "resources"=>
      [{"properties"=>
        {"parameters"=>
          {"vNetName"=>{"value"=>"[parameters('vNetName')]"},
            "vNet"=>{"value"=>"[parameters('vNet')]"},
            "subnets_array"=>{"value"=>"[parameters('subnets_array')]"},
            "sharedKey"=>{"value"=>"[parameters('sharedKey')]"},
            "create_peers"=>{"value"=>"[parameters('create_peers')]"}},
          "templateLink"=>{"uri"=>"./arm_templates/networks/nsgs.json"}}}]}
    assert_equal(result, $wraztm.sanitize_template_params(template))
  end

  def test_inject_parameters_to_template()
    raw_template = {"./arm_templates/networks/nsgs.json"=>"{\"parameters\":{},\"resources\":[{\"properties\":{\"parameters\":{}}}]}"}
    params_hash = {"vNetName"=>{"type"=>"string"},
      "vNet"=>{"type"=>"object"},
       "subnets_array"=>{"type"=>"array"},
      "sharedKey"=>{"type"=>"securestring"},
      "create_peers"=>{"type"=>"bool"}}
    result = {"./arm_templates/networks/nsgs.json"=>
      "{\n  \"parameters\": {\n    \"vNetName\": {\n      \"type\": \"string\"\n    },\n    \"vNet\": {\n      \"type\": \"object\"\n    },\n    \"subnets_array\": {\n      \"type\": \"array\"\n    },\n    \"sharedKey\": {\n      \"type\": \"securestring\"\n    },\n    \"create_peers\": {\n      \"type\": \"bool\"\n    }\n  },\n  \"resources\": [\n    {\n      \"properties\": {\n        \"parameters\": {\n        }\n      }\n    }\n  ]\n}"}
    assert_equal(result, $wraztm.inject_parameters_to_template(raw_template, params_hash))
  end
end
