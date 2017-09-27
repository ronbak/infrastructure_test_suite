require 'json'
require 'uri'
require 'net/http'
require 'openssl'

class ::Hash
  def deep_merge(second)
    merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : Array === v1 && Array === v2 ? v1 | v2 : [:undefined, nil, :nil].include?(v2) ? v1 : v2 }
    self.merge(second.to_h, &merger)
  end
end

def encrypt(string)
  cipher = OpenSSL::Cipher::Cipher.new('aes-256-cfb8').encrypt
  cipher.key = Digest::SHA256.hexdigest key()
  s = cipher.update(string) + cipher.final

  s.unpack('H*')[0].upcase
end

def decrypt(enc_txt)
  cipher = OpenSSL::Cipher::Cipher.new('aes-256-cfb8').decrypt
  cipher.key = Digest::SHA256.hexdigest key()
  s = [enc_txt].pack("H*").unpack("C*").pack("c*")

  cipher.update(s) + cipher.final
end

def key()
  key_file = "#{ENV['HOME']}/.ssh/azure_ruby_key" 
  if File.exist?(key_file)
    key = File.read(key_file)
  else
    key = OpenSSL::PKey::RSA.new 2048
    open key_file, 'w' do |io| io.write key.to_pem end
    key = key.to_pem
  end
  return key
end

def wrmetadata()
  return JSON.parse(File.read("#{File.dirname(__FILE__)}/../metadata/metadata.json"))
end

def wrmetadata_regex(resource_type)
  data = JSON.parse(File.read("#{File.dirname(__FILE__)}/../metadata/metadata.json"))
  regex_obj = data['global']['naming_standards']['regexes'].find { |obj| obj['resource_types'].include?(resource_type) }
  return regex_obj['pattern'] unless regex_obj.nil?
  return nil
end

def wrenvironmentdata(environment)
  data = wrmetadata()
  data.find { |stanza| stanza[1]['synonyms'].include?(environment.downcase)}[1]
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

def retrieve_from_internet_anonymous(url)
  uri = URI(url)
  https = Net::HTTP.new(uri.host, uri.port, nil)
  https.use_ssl = true
  https.verify_mode = OpenSSL::SSL::VERIFY_NONE
  req = Net::HTTP::Get.new(uri.request_uri)
  res = https.request(req)
  return res.body
end

def convert_git_raw_to_api(url)
  github_api_url = 'https://api.github.com/repos'
  github_raw_url = 'https://raw.githubusercontent.com'
  if url[0..32] == github_raw_url
    url.sub! github_raw_url, github_api_url
    url.sub! url.split(github_api_url)[-1].split('/')[3], 'contents'
    return url
  elsif url[0..27] == github_api_url
    return url
  else
    @csrelog.error("We couldn't convert the url supplied to use GitHub api. 
      #{url}
      Please use either a github api url or a github raw.usercontent url")
    #exit 1
  end
end

def retrieve_from_github_api(url, access_token)
  uri = URI(url)
  https = Net::HTTP.new(uri.host, uri.port)
  https.use_ssl = true
  https.open_timeout = 5
  https.verify_mode = OpenSSL::SSL::VERIFY_PEER
  req = Net::HTTP::Get.new(uri.request_uri)
  req['Authorization'] = "token #{access_token}"
  req['Accept'] = 'application/vnd.github.v3.raw'
  res = https.request(req)
  return res.body
end

def retrieve_from_gitlab_api(url, access_token)
  uri = URI(url)
  https = Net::HTTP.new(uri.host, uri.port)
  https.use_ssl = true
  https.open_timeout = 5
  https.verify_mode = OpenSSL::SSL::VERIFY_NONE
  req = Net::HTTP::Get.new(uri.request_uri)
  req['PRIVATE-TOKEN'] = "#{access_token}"
  req['Accept'] = 'application/vnd.github.v3.raw'
  res = https.request(req)
  return res.body
end

def query_wr_web_servers(ip_counter, host_header)
  response = {up: [], down: []}
  ip_counter.each do |ip|
    uri = URI("https://#{ip}")
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    https.open_timeout = 2
    https.verify_mode = OpenSSL::SSL::VERIFY_NONE
    req = Net::HTTP::Get.new(uri.request_uri)
    req['Host'] = host_header
    begin 
      res = https.request(req)
      if res.body.length >= 3500
        puts "Server #{ip} is up and running"
        response[:up] << ip
      else
        puts "\n\n*********************\nit doesn't look good for\n#{ip}\n*********************\n\n#{res.body}\n*********************\n\n"
        response[:down] << ip
      end
    rescue Net::OpenTimeout => e
      puts "\nERROR: #{ip} timed out\n#{e}\n"
      response[:down] << ip
    rescue => e
      puts "There was another error check it\n#{e}"
      response[:down] << ip
    end
  end
  return response
end