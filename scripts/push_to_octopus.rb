require 'rubygems'
require 'bundler/setup'
require 'rest-client'
require 'json'
require 'optparse'
require 'net/http/post/multipart'
require_relative '../lib/global_methods'

# Setting up arguments

options = {}
OptionParser.new do |opt|
  opt.on('-a', '--api_key API_KEY') { |o| options[:api_key] = o }
  opt.on('-u', '--octopus_url OCTOPUS_URL') { |o| options[:octopus_url] = o }
  opt.on('-f', '--file_name FILE_NAME') { |o| options[:file_name] = o }
end.parse!

# Setting up parameters
api_header = "X-Octopus-ApiKey"
api_key = options[:api_key]
octopus_url = 'https://octopusdeploy.worldremit.com'
octopus_url = options[:octopus_url] unless options[:octopus_url].nil?
file_name = options[:file_name]

package_version = file_name.gsub("#{file_name.split('.')[0]}.", "").gsub(".#{file_name.split('.')[-1]}", "")
api_auth = { api_header => api_key }

puts "[STATUS] Uploading package #{file_name}..."

begin
  upload_package_to_octopus(octopus_url, file_name, api_key)
rescue => e
  puts e
  raise 'Failed to upload package'
end
