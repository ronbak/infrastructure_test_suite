require 'json'
require 'uri'
require 'net/http'
require 'openssl'

def wrmetadata()
  return JSON.parse(File.read("#{File.dirname(__FILE__)}/../metadata/metadata.json"))
end

def wrmetadata_regex(resource_type)
  data = JSON.parse(File.read("#{File.dirname(__FILE__)}/../metadata/metadata.json"))
  regex_obj = data['global']['naming_standards']['regexes'].find { |obj| obj['resource_types'].include?(resource_type) }
  return regex_obj['pattern'] unless regex_obj.nil?
  return nil
end

def valid_json?(json)
  begin
    JSON.parse(json)
    return true
  rescue
  end
  return false
end

def create_deployment_name()
  "armRubyAutomation-#{Time.now.strftime("%d%m%y%H%M%S")}"
end

def uri?(string)
  uri = URI.parse(string)
  %w( http https ).include?(uri.scheme)
rescue URI::BadURIError
  false
rescue URI::InvalidURIError
  false
end

def caesar_cipher(s, step: 1, decrypt: false)
  process_str = ''
  s.split('').each do |letter|
    if decrypt
      process_str += (letter.ord - step).chr()
    else
      step.times do
        letter = letter.next()
      end
      process_str += letter
    end
  end
  return process_str
end

def get_data_from_url(url)
  uri = URI(url)
  https = Net::HTTP.new(uri.host, uri.port, nil)
  https.use_ssl = true
  https.verify_mode = OpenSSL::SSL::VERIFY_NONE
  req = Net::HTTP::Get.new(uri.request_uri)
  res = https.request(req)
  return res
end
