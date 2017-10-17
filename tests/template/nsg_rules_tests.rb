require 'json'

require_relative 'WRGit'
require_relative 'WRTemplateTester'
require 'minitest/reporters'
require 'minitest/autorun'
MiniTest::Reporters.use! [MiniTest::Reporters::DefaultReporter.new,
                          MiniTest::Reporters::JUnitReporter.new]


$path = ARGV[0]
$commit = ARGV[1]
$previous_commit = ARGV[2]
$files = WRGit.new($path).diff_files($commit, $previous_commit)
puts $path
puts $previous_commit
puts $commit
puts "these are your files: #{$files}"


class TestWRTemplate <  MiniTest::Test

  def setup()
  end

  def test_nsg_rules
    $files.each do |template|
      if template.first.include?('/nsg_rules/')
        puts "Performing a NSG rules template test set"
        tester = WRTemplatesTester.new(template.first)
        subnet_info = tester.allowed_subnet_names()
        rules_array = tester.template['resources']
        rules_array.each do |rule_object|
          puts "We are now testing rule: #{rule_object['name']}\nWith DestinationAddressprefix of: #{rule_object['properties']['destinationAddressPrefix']}"
          puts "From file: #{template.first}\n\n\n"
          refute_equal('*', rule_object['properties']['destinationPortRange']) unless rule_object['properties']['sourceAddressPrefix'] == 'VirtualNetwork'
          assert_equal(false, tester.valid_cidr?(rule_object['properties']['destinationAddressPrefix']))
          assert_equal('*', rule_object['properties']['sourcePortRange'])
          if subnet_info[0].include?(rule_object['properties']['sourceAddressPrefix'])
            assert_includes(subnet_info[0], rule_object['properties']['sourceAddressPrefix'])
          elsif tester.valid_cidr?(rule_object['properties']['sourceAddressPrefix'])
            assert_equal(false, tester.disallowed_subnet_cidr?(rule_object['properties']['sourceAddressPrefix'], subnet_info[1]))
          else
            assert_equal(false, rule_object['properties']['sourceAddressPrefix'])
          end
        end
      end
    end
  end

end
