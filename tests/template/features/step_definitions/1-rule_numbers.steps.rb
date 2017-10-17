require_relative '../../../../lib/WRConfigManager'

Given(/^a generated (.*) ARM template$/) do |template|
  @template = Dir.entries('.').find { |file| file.name.include?(template) }
end

When(/^I parse the template$/) do
  @template_hash = WRConfigManager.new(config: @template).config
end

Then(/^it should contain 4 subnets for each landscape$/) do
  expect(@installed_version).to eq(expected_version)
end