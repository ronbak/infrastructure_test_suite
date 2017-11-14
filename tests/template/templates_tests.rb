require 'json'
require_relative 'WRGit'
require_relative 'WRTemplateTester'
require_relative '../../lib/global_methods'
require 'minitest/reporters'
require 'minitest/autorun'
MiniTest::Reporters.use! [MiniTest::Reporters::DefaultReporter.new,
                          MiniTest::Reporters::JUnitReporter.new]


if ENV['changed_files']
  puts "Running the changed files file in TC #{ENV['changed_files']}"
  puts ENV['changed_files']
  $files = {}
  files = File.read(ENV['changed_files'])
  print files
  files.split(' ').each do |file_string|
    if file_string.include?(':ADDED:')
      $files[file_string.split(':ADDED:')[0]] = file_string.split(':ADDED:')[-1]
    elsif file_string.include?(':CHANGED:')
      $files[file_string.split(':CHANGED:')[0]] = file_string.split(':CHANGED:')[-1]
    else
      $files[file_string.split(':')[0]] = file_string.split(':')[-1]
    end
  end
else
  puts "Running the changes direct from a git repo diff command"
  $path = ARGV[0]
  $commit = ARGV[1]
  $previous_commit = ARGV[2]
  $files = WRGit.new($path).diff_files($commit, $previous_commit)
  puts $path
  puts $previous_commit
  puts $commit
end
puts "these are your files: #{$files}"


networks_to_deploy = []
$files.keys.each do |file_path|
  if file_path.include?('networks/nsg_rules/nsg_rules_core_')
    networks_to_deploy << 'core'
  elsif file_path.include?('networks/nsg_rules/nsg_rules_')
    networks_to_deploy << 'nonprd'
  else
    networks_to_deploy << 'none'
  end
end
if networks_to_deploy.uniq.count.equal?(3)
  deploy_string = 'both'
elsif networks_to_deploy.uniq.include?('nonprd') && networks_to_deploy.uniq.include?('core')
  deploy_string = 'both'
elsif networks_to_deploy.uniq.include?('nonprd')
  deploy_string = 'nonprd'
elsif networks_to_deploy.uniq.include?('core')
  deploy_string = 'core'
elsif networks_to_deploy.uniq.include?('none')
  deploy_string = 'none'
end
puts 'writing file'
write_file('networks_to_deploy.txt', deploy_string)

class TestWRTemplate <  MiniTest::Test

  def setup()
  end

  def test_nsg_rules
    $files.each do |template|
      if template.first.include?('/nsg_rules/')
        puts "Performing a NSG rules template test set"
        tester = WRTemplatesTester.new(template.first)
        puts template.first
        puts "#{File.dirname(template.first)}/../configs/"
        subnet_info = tester.allowed_subnet_names("#{File.dirname(template.first)}/../configs/")
        puts "These are your allowed subnet names: #{subnet_info}"
        rules_array = tester.template['resources']
        rules_array.each do |rule_object|
          puts "We are now testing rule: #{rule_object['name']}\nWith DestinationAddressprefix of: #{rule_object['properties']['destinationAddressPrefix']}"
          puts "From file: #{template.first}\n\n\n"
          # Test for no 'Any' rule in destination port unless it's coming from the local vNet
          refute_equal('*', rule_object['properties']['destinationPortRange']) unless rule_object['properties']['sourceAddressPrefix'] == 'VirtualNetwork'
          # test that destination address is not a valid CIDR (it should be a generic subnet name, i.e private, public, etc etc)
          assert_equal(false, tester.valid_cidr?(rule_object['properties']['destinationAddressPrefix']))
          # ensure sourec port is set to 'Any'
          assert_equal('*', rule_object['properties']['sourcePortRange'])
          # Ensure protocol is either tcp udp or any
          assert_includes(['Tcp', 'Udp', '*'], rule_object['properties']['protocol'])
          # Ensure source address is either a subnet from the vNet
          if subnet_info[0].include?(rule_object['properties']['sourceAddressPrefix'])
            assert_includes(subnet_info[0], rule_object['properties']['sourceAddressPrefix'])
          # if it's a valid CIDR that it's not in the local vnet (prd and nonprd, NOT core) 
          elsif tester.valid_cidr?(rule_object['properties']['sourceAddressPrefix'])
            assert_equal(false, tester.disallowed_subnet_cidr?(rule_object['properties']['sourceAddressPrefix'], subnet_info[1]))
          else
          # default fail, the previous 2 options should catch all rules, if not there is an error and should fail.
            assert_equal(false, rule_object['properties']['sourceAddressPrefix'])
          end
        end
        inbound_priority = []
        inbound_rules = rules_array.select { |rule| rule['properties']['direction'] == 'Inbound' }
        inbound_rules.each do |rule|
          inbound_priority << rule['properties']['priority']
        end
        outbound_priority = []
        outbound_rules = rules_array.select { |rule| rule['properties']['direction'] == 'Outbound' }
        outbound_rules.each do |rule| 
          outbound_priority << rule['properties']['priority']
        end
        # validate there are no  duplicate priorities or rule numbers
        assert_empty(inbound_priority.group_by{ |e| e }.select { |k, v| v.size > 1 }.keys, 'You have a duplicate priority / rule number on your inbound rules')
        assert_empty(outbound_priority.group_by{ |e| e }.select { |k, v| v.size > 1 }.keys, 'You have a duplicate priority / rule number on your outbound rules')
        assert_nil(rules_array.detect{ |e| rules_array.count(e) > 1 }, "You have a duplicate rule object in your template")
      end
    end
  end

  def test_policy_templates
    $files.each do |template|
      if template.first.include?('/policies/')
        puts "Performing a policy template test set: #{template.first}"
        assert_equal(true, valid_json?(File.read(template.first)))
      end
    end
  end

  def test_valid_json
    $files.each do |template|
      if template[-5..-1].eql?('.json')
        puts "Validating JSON for template: #{template.first}"
        assert_equal(true, valid_json?(File.read(template.first)))
      end
    end
  end

end

