require 'json'
require_relative 'WRTemplateTester'
require_relative '../../lib/global_methods'
require 'minitest/reporters'
require 'minitest/autorun'
MiniTest::Reporters.use! [MiniTest::Reporters::DefaultReporter.new,
                          MiniTest::Reporters::JUnitReporter.new]


$files = Dir['*.json']

class TestWRTemplate <  MiniTest::Test

  def setup()
  end

  def test_nsgs
    $files.each do |template|
      if template.include?('.nsgs') && !template.include?('external')
        puts "Performing a NSG rules template test set"
        tester = WRTemplatesTester.new(template)
        subnet_info = tester.allowed_subnet_names()
        nsgs_array = tester.template['resources']
        assert_operator(nsgs_array.count, :>=, 24)
        count = 0
        nsgs_array.each do |nsg|
          count += nsg['properties']['securityRules'].count
        end
        assert_operator(count, :>=, 150)
      end
    end
  end

  def test_valid_json
    $files.each do |template|
      puts "Validating JSOn for template: #{template}"
      assert_equal(true, valid_json?(File.read(template)))
    end
  end

end

