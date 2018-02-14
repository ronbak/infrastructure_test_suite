require 'net/http'
require 'openssl'
require 'json'
require 'digest'
require 'base64'
require 'optparse'
require 'ostruct'
require 'pry-byebug'


@options = OpenStruct.new
@options[:environment] = 'nonprd'
@options[:url] = 'https://jenkins.csre.worldremit.com'
@options[:job] = 'csre/job/ResourceGroup-Create_or_Update'
@options[:jobtoken] = ''

def parse_args(args)
  opt_parser = OptionParser.new do |opts|
    opts.banner = 'Usage: create_rgs_jenkins.rb [options]'
    opts.on('-u user', '--user user', 'The Jenkins users this job will run against') do |user|
      @options[:user] = user
    end
    opts.on('-t user token', '--token user token', 'jenkins user token') do |token|
      @options[:token] = token
    end
    opts.on('-e environment', '--environment environment', 'Environment you are creating RG\'s for') do |environment|
      @options[:environment] = environment
    end
    opts.on('-p template', '--template template', 'Path or Git url to the template you\'re deploying') do |template|
      @options[:template] = template
    end
    opts.on('-u jenkinsURL', '--url jenkinsURL', 'URL to your jenkins system') do |url|
      @options[:url] = url
    end
    opts.on('-j jobName', '--job jobName', 'The path name to your job in Jenkins, e.g. \'csre/job/myfirstjob\'') do |job|
      @options[:job] = job
    end
    opts.on('-b jobToken', '--job-token jobToken', 'The job specific remote trigger token') do |jobtoken|
      @options[:jobtoken] = jobtoken
    end
  end
  opt_parser.parse!(args)

  if @options[:user].nil? || @options[:token].nil? || @options[:template].nil?
    puts 'you\'re missing the --user or --token or --template option.'
    exit
  end
  
end

parse_args(ARGV)

user = @options.user
environment = @options.environment
template = @options.template
token = @options.token
jenkinsURL = @options.url
jobName = @options.job
jobToken = @options.jobtoken

def invoke_webrequest(url, headers, reqmethod = 'GET', body = {})
  uri = URI(url)
  https = Net::HTTP.new(uri.host, uri.port, nil)
  https.use_ssl = true
  https.verify_mode = OpenSSL::SSL::VERIFY_PEER
  case reqmethod
  when 'POST'
    req = Net::HTTP::Post.new(uri.request_uri)
    req.body = 'json=' + body.to_json
  when 'GET'
    req = Net::HTTP::Get.new(uri.request_uri)
  end
  headers.each do |key, value|
    req[key] = value
  end
  res = https.request(req)
  return res
end

# get template
unless template[0..7].downcase.eql?('https://')
  template = File.read(template)
end


# Setup auth header
auth = user + ':' + token

# Create authentication header
base64Bytes = Base64.encode64(auth).gsub("\n", '')

# Get jenkins crumb to prevent CSRF
crumbIssuer = "#{jenkinsURL}/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)"
headers = { "Authorization" => "Basic #{base64Bytes}" }
crumb = invoke_webrequest(crumbIssuer, headers).body.split(":")[-1]
headers['Jenkins-Crumb'] = crumb


# Construct Request
fullURL = "#{jenkinsURL}/job/#{jobName}/build?token=#{jobToken}"
body = {"parameter" => [{"name" => "environment", "value" => environment}, {"name" => "template", "value" => template}]}
res = invoke_webrequest(fullURL, headers, 'POST', body)


if res.code.eql?('201')
  puts "Your job request was accepted by the server, querying the console......."
  # Query Jenkins API for build number
  api = "api/json"
  apiUrl = "#{jenkinsURL}/job/#{jobName}/#{api}"
  builds = JSON.parse(invoke_webrequest(apiUrl, headers).body)['builds']
  buildnumber = builds.sort_by { |obj| obj['number'] }[-1]['number']
  
  # Query API to get the build status
  buildUrl = "#{jenkinsURL}/job/#{jobName}/#{buildnumber}/#{api}"
  #obj = JSON.parse(invoke_webrequest(buildUrl, headers).body)
  
  # Query API to get the build console messages
  consoleUrl = "#{jenkinsURL}/job/#{jobName}/#{buildnumber}/consoleText"
  console = ''
  begin
    sleep 0.5
    obj = JSON.parse(invoke_webrequest(buildUrl, headers).body)
    consoleupdate = invoke_webrequest(consoleUrl, headers).body
    if console.length != 0
      outputconsole = consoleupdate.gsub(console, '')
      print outputconsole
      console += outputconsole
    else
      print consoleupdate
      console += consoleupdate
    end
  end until obj['building'].eql?(false)
  
  if obj['result'].eql?('SUCCESS')
    puts "Your job finished with MASSIVE success"
  else
    puts "your job failed\n#{obj['result']}"
  end
else
  puts "The job was not created, error code: #{res.code}"
end
