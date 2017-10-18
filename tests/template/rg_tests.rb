require 'json'
require_relative '../../lib/WRConfigManager'
require 'minitest/reporters'
require 'minitest/autorun'
MiniTest::Reporters.use! [MiniTest::Reporters::DefaultReporter.new,
                          MiniTest::Reporters::JUnitReporter.new]


class TestRGTemplate <  MiniTest::Test

  def setup()
  end

  def test_rg_template
    template = WRConfigManager.new(config: ENV['template']).config
    run_models = ['9-5', 'm-f', '247']
    locations = ['WestEurope', 'NorthEurope']
    # Verify JSON
    assert_kind_of(Hash, template)
    # Verify maximum of 4 elements in the config
    assert_operator(4, :<=, template.keys.count)
    # Verify all 5 tags are included
    assert_operator(5, :==, template['tags'].keys.count)
    # Verify each element is included and all tags are present
    assert_equal(true, template.keys.include?('name'), 'You\'re missing the name element')
    assert_equal(true, template.keys.include?('access_group_id'), 'You\'re missing the access_group_id element')
    assert_equal(true, template.keys.include?('tags'), 'You\'re missing the tags element')
    assert_instance_of(Hash, template['tags'], "Your tags object is not a hash")
    assert_equal(true, template['tags'].keys.include?('OwnerContact'), 'You\'re missing the OwnerContact tag')
    assert_equal(true, template['tags'].keys.include?('Team'), 'You\'re missing the Team tag')
    assert_equal(true, template['tags'].keys.include?('Location'), 'You\'re missing the Location tag')
    assert_equal(true, template['tags'].keys.include?('Project'), 'You\'re missing the Project tag')
    assert_equal(true, template['tags'].keys.include?('RunModel'), 'You\'re missing the RunModel tag')
    # Verify values for each key
    assert_equal([template['tags']['OwnerContact']], template['tags']['OwnerContact'].scan(/[a-zA-Z0-9]*@worldremit.com/), "You have not supplied a worldremit email address in the OwnerContact tag")
    assert_includes(run_models, template['tags']['RunModel'], "You must supply one of: #{run_models} in the RunModel tag")
    assert_equal([template['tags']['Project']], template['tags']['Project'].scan(/[a-zA-Z]{3,6}-[0-9]{3,5} - [a-zA-Z0-9\s]*/), "Project tag must star with a Jira ticket followed by, ' - ' and a description")    
    assert_includes(locations, template['tags']['Location'], "Location tag must be one of #{locations}")
    assert_equal([template['tags']['Team']], template['tags']['Team'].scan(/[a-zA-Z0-9\s]{2,32}/), "Team tag must contain only alpha numeric characters and white space and be no more than 32 characters")
    assert_equal([template['access_group_id']], template['access_group_id'].scan(/[a-zA-Z0-9]{8}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{12}/), "Access group must be a valid GUID reference")
    assert_equal([template['name']], template['name'].scan(/[a-zA-Z0-9\-\_]{2,64}/), "name element must contain only alphanumeric characters and '-' or '_', It can be no longer than 64 characters")
  end

end

