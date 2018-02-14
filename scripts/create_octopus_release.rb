require 'rubygems'
require 'bundler/setup'
require 'rest-client'
require 'json'
require 'optparse'
require 'net/http/post/multipart'
require_relative '../lib/global_methods'
require_relative '../lib/CSRELogger'
require 'pry-byebug'

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

# Setup logger
log_level = 'INFO'
log_level = ENV['CSRE_LOG_LEVEL'] unless ENV['CSRE_LOG_LEVEL'].nil?
csrelog = CSRELogger.new(log_level, 'STDOUT')


package_version = file_name.gsub("#{file_name.split('.')[0]}.", "").gsub(".#{file_name.split('.')[-1]}", "")
csrelog.info("[STATUS] Package Version: #{package_version}")
api_auth = { api_header => api_key }

csrelog.info("[STATUS] Uploading package #{file_name}...")

begin
  upload_package_to_octopus(octopus_url, file_name, api_key, api_header) if file_name
rescue => e
  csrelog.error(e)
  raise 'Failed to upload package'
end

# Getting ID's

csrelog.info("[STATUS] Getting project and environment ID's...")

project_response = RestClient.get "#{octopus_url}/api/projects/#{project_name}", api_auth
project = JSON.parse(project_response.body)

environment_response = RestClient.get "#{octopus_url}/api/Environments/all", api_auth
environment = JSON.parse(environment_response.body)
environment = environment.select {|key| key["Name"] == environment_name }.first

csrelog.info("[OK] Project ID: #{project['Id']}")
csrelog.info("[OK] Environment ID: #{environment['Id']}")



# Get channel ID's

channels_response = RestClient.get "#{octopus_url}/api/projects/#{project['Id']}/channels", api_auth
channels = JSON.parse(channels_response.body)


# Getting Deployment Template

csrelog.info("[STATUS] Getting Deployment Template...")

deploy_template_response = RestClient.get "#{octopus_url}/api/deploymentprocesses/deploymentprocess-#{project['Id']}/template", api_auth
deploy_template = JSON.parse(deploy_template_response.body)

csrelog.info("[OK] Deployment Template Next Version Increment: #{deploy_template['NextVersionIncrement']}")

# Creating Release
if file_name
  csrelog.info("[STATUS] Creating Release...")
  
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
    csrelog.error("\n[ERROR] ERROR while trying to create release!")
    csrelog.error("[ERROR] Error Message: #{errors['ErrorMessage']}")
    errors["Errors"].each do |err|
      csrelog.error("--------------------------------")
      csrelog.error("#{err}")
      csrelog.error("--------------------------------")
    end
    raise "Failed to create Release!"
  end
  
  
  release = JSON.parse(release_request.body)
  
  csrelog.info("[OK] Release ID: #{release['Id']}")
  csrelog.info("[OK] Release created on URL: #{octopus_url}/app\#/projects/#{project_name}/releases/#{deploy_template['NextVersionIncrement']}")
else
  releases = JSON.parse(RestClient.get("#{octopus_url}#{project['Links']['Releases'].split('{')[0]}", api_auth).body)
  release = releases['Items'].max_by do |element|
    element['Version'].to_i
  end
  csrelog.info("[OK] Release ID: #{release['Id']}")
  csrelog.info("[OK] Release Version: #{release['Version']}")
  csrelog.info("[OK] Promoting to #{environment['Name']}")
end

# Creating Deployment

csrelog.info("[STATUS] Creating Deployment...")

deployment_body = JSON.generate({ :ReleaseId => release["Id"], :EnvironmentId => environment["Id"]})

begin
  deployment_request = RestClient.post "#{octopus_url}/api/deployments", deployment_body, api_auth
rescue RestClient::ExceptionWithResponse => deploy_error
  errors = JSON.parse(deploy_error.response.body)
  csrelog.error("\n[ERROR] ERROR while trying to create deployment!")
  csrelog.error("[ERROR] Error Message: #{errors['ErrorMessage']}")
  errors["Errors"].each do |err|
    csrelog.error("--------------------------------")
    csrelog.error("#{err}")
    csrelog.error("--------------------------------")
  end
  raise "Failed to create Deployment!"
end

deployment_response = JSON.parse(deployment_request.body)

csrelog.info("[OK] Deployment created on URL: #{octopus_url}#{deployment_response['Links']['Web']}")


status = JSON.parse(RestClient.get("#{octopus_url}#{deployment_response['Links']['Task']}", api_auth).body)
displayed_logs = []
while status['IsCompleted'].eql?(false)
  sleep 5
  details = JSON.parse(RestClient.get("#{octopus_url}#{status['Links']['Details'].split('{')[0]}", api_auth).body)
  details['ActivityLogs'].first['Children'].each do |step|
    step['Children'].each do |child_step|
      child_step['LogElements'].each do |log_element|
        csrelog.info("#{step['Name']} - #{child_step['Name']} - Message: #{log_element['MessageText']}") unless displayed_logs.include?(log_element)
        displayed_logs << log_element
      end
    end
  end
  status = JSON.parse(RestClient.get("#{octopus_url}#{deployment_response['Links']['Task']}", api_auth).body)
end

if status['FinishedSuccessfully']
  csrelog.info("[OK] Deployment completed successfully")
  exit
else
  csrelog.error("The deployment status is: #{JSON.pretty_generate(JSON.parse(RestClient.get(octopus_url + status['Links']['Details'], api_auth).body))}")
  exit 1
end
