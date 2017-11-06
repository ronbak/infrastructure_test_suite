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
  opt.on('-p', '--project_name PROJECT_NAME') { |o| options[:project_name] = o }
  opt.on('-e', '--env_name ENVIRONMENT_NAME') { |o| options[:environment_name] = o }
  opt.on('-f', '--file_name FILE_NAME') { |o| options[:file_name] = o }
  opt.on('-s', '--step_name STEP_NAME') { |o| options[:step_name] = o }
end.parse!

# Setting up parameters

api_header = "X-Octopus-ApiKey"
api_key = options[:api_key]
octopus_url = 'https://octopusdeploy.worldremit.com'
octopus_url = options[:octopus_url] unless options[:octopus_url].nil?
project_name = options[:project_name]
environment_name = options[:environment_name]
file_name = options[:file_name]
step_name = options[:step_name]

step_names = step_name.split(' ')

package_version = file_name.gsub("#{file_name.split('.')[0]}.", "").gsub(".#{file_name.split('.')[-1]}", "")
api_auth = { api_header => api_key }



puts "[STATUS] Uploading package #{file_name}..."

begin
  upload_package_to_octopus(octopus_url, file_name, api_key)
rescue => e
  puts e
  raise 'Failed to upload package'
end

# Getting ID's

puts "[STATUS] Getting project and environment ID's..."

project_response = RestClient.get "#{octopus_url}/api/projects/#{project_name}", api_auth
project = JSON.parse(project_response.body)

environment_response = RestClient.get "#{octopus_url}/api/Environments/all", api_auth
environment = JSON.parse(environment_response.body)
environment = environment.select {|key| key["Name"] == environment_name }.first

puts "[OK] Project ID: #{project['Id']}"
puts "[OK] Environment ID: #{environment['Id']}"



# Get channel ID's

channels_response = RestClient.get "#{octopus_url}/api/projects/#{project['Id']}/channels", api_auth
channels = JSON.parse(channels_response.body)


# Getting Deployment Template

puts "[STATUS] Getting Deployment Template..."

deploy_template_response = RestClient.get "#{octopus_url}/api/deploymentprocesses/deploymentprocess-#{project['Id']}/template", api_auth
deploy_template = JSON.parse(deploy_template_response.body)

puts "[OK] Deployment Template Next Version Increment: #{deploy_template['NextVersionIncrement']}"

# Creating Release

puts "[STATUS] Creating Release..."

selected_packages = []
step_names.each do |step|
  selected_packages << { :StepName => step, :Version => package_version }
end


release_body = JSON.generate({ :ProjectId => project['Id'], :Version => deploy_template["NextVersionIncrement"], :ChannelId => channels['Items'].first['Id'],
  :SelectedPackages => selected_packages })

begin
  release_request = RestClient.post "#{octopus_url}/api/releases", release_body, api_auth
rescue RestClient::ExceptionWithResponse => release_error
  errors = JSON.parse(release_error.response.body)
  puts "\n[ERROR] ERROR while trying to create release!"
  puts "[ERROR] Error Message: #{errors['ErrorMessage']}"
  errors["Errors"].each do |err|
    puts "--------------------------------"
    puts "#{err}"
    puts "--------------------------------"
  end
  raise "Failed to create Release!"
end


release = JSON.parse(release_request.body)

puts "[OK] Release ID: #{release['Id']}"

puts "[OK] Release created on URL: #{octopus_url}/app\#/projects/#{project_name}/releases/#{deploy_template['NextVersionIncrement']}"

# Creating Deployment

puts "[STATUS] Creating Deployment..."

deployment_body = JSON.generate({ :ReleaseId => release["Id"], :EnvironmentId => environment["Id"]})

begin
  deployment_request = RestClient.post "#{octopus_url}/api/deployments", deployment_body, api_auth
rescue RestClient::ExceptionWithResponse => deploy_error
  errors = JSON.parse(deploy_error.response.body)
  puts "\n[ERROR] ERROR while trying to create deployment!"
  puts "[ERROR] Error Message: #{errors['ErrorMessage']}"
  errors["Errors"].each do |err|
    puts "--------------------------------"
    puts "#{err}"
    puts "--------------------------------"
  end
  raise "Failed to create Deployment!"
end

deployment_response = JSON.parse(deployment_request.body)

puts "[OK] Deployment created on URL: #{octopus_url}#{deployment_response['Links']['Web']}"
exit