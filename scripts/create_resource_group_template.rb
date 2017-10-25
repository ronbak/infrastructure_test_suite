require 'json'
require_relative '../lib/global_methods'

group_data = JSON.parse(File.read("#{File.dirname(__FILE__)}/create_resource_group_metadata.json"))
template = {}
template['name'] = ENV['name']
template['access_group_id'] = group_data[ENV['group_name']]
template['universal'] = true
tags = {}
tags['OwnerContact'] = ENV['OwnerContact']
tags['Team'] = ENV['Team']
tags['Location'] = ENV['Location']
tags['Project'] = ENV['Project']
tags['RunModel'] = ENV['RunModel']
template['tags'] = tags

write_hash_to_disk(template, "#{template['name']}.json")

