require 'rubygems'
require 'bundler/setup'
require 'rest-client'
require 'json'
require 'optparse'
require 'net/http/post/multipart'

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
octopus_url = options[:octopus_url]
project_name = options[:project_name]
environment_name = options[:environment_name]
file_name = options[:file_name]
step_name = options[:step_name]

package_version = file_name.gsub("#{file_name.split('.')[0]}.", "").gsub(".#{file_name.split('.')[-1]}", "")
api_auth = { api_header => api_key }



puts "[STATUS] Uploading package #{file_name}..."

begin 
  url = URI.parse("#{octopus_url}/api/packages/raw")
  File.open(file_name) do |payload|
    req = Net::HTTP::Post::Multipart.new url.path,
      "file" => UploadIO.new(payload, "bin/zip", package_file)
    req[api_header] = api_key
    https = Net::HTTP.new(url.host, url.port)
    https.use_ssl = true
    res = https.request(req)
  end
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

# Getting Deployment Template

puts "[STATUS] Getting Deployment Template..."

deploy_template_response = RestClient.get "#{octopus_url}/api/deploymentprocesses/deploymentprocess-#{project['Id']}/template", api_auth
deploy_template = JSON.parse(deploy_template_response.body)

puts "[OK] Deployment Template Next Version Increment: #{deploy_template['NextVersionIncrement']}"

# Creating Release

puts "[STATUS] Creating Release..."

release_body = JSON.generate({ :ProjectId => project['Id'], :Version => deploy_template["NextVersionIncrement"], :ChannelId => 'Channels-409',
  :SelectedPackages => [{:StepName => step_name, :Version => package_version}] })

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