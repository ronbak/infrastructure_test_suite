require 'openssl'
require 'json'
require 'net/http'
require 'resolv'
require_relative 'CSRELogger'
require_relative 'global_methods'
require 'pry-byebug'

class WRUltraDNSManagement

  def initialize(username, password)
    @api = "https://restapi.ultradns.com/v2/zones/"
    @token = get_access_token(username, password)
    log_level = 'INFO'
    log_level = ENV['CSRE_LOG_LEVEL'] unless ENV['CSRE_LOG_LEVEL'].nil?
    @csrelog = CSRELogger.new()
  end

  def get_access_token(username, password, url = 'https://restapi.ultradns.com/v2/authorization/token')
    uri = URI(url)
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    req = Net::HTTP::Post.new(uri.request_uri)
    req.set_form_data({'grant_type' => 'password', 'username' => username, 'password' => password})
    res = https.request(req)
    return JSON.parse(res.body)
  end

  def refresh_access_token(refresh_token, url = 'https://restapi.ultradns.com/v2/authorization/token')
    uri = URI(url)
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    req = Net::HTTP::Post.new(uri.request_uri)
    req.set_form_data({'grant_type' => 'refresh_token', 'refresh_token' => refresh_token})
    res = https.request(req)
    return JSON.parse(res.body)
  end

  def query_api(token, url)
    uri = URI(url)
    req = Net::HTTP::Get.new(uri.request_uri)
    res = process_request_rest_api(req, uri, token)
    return JSON.parse(res.body)
  end

  def post_api(token, url, body)
    uri = URI(url)
    req = Net::HTTP::Post.new(uri.request_uri)
    res = process_request_rest_api(req, uri, token, body)
    return JSON.parse(res.body)
  end

  def put_api(token, url, body)
    uri = URI(url)
    req = Net::HTTP::Put.new(uri.request_uri)
    res = process_request_rest_api(req, uri, token, body)
    return JSON.parse(res.body)
  end  

  def process_request_rest_api(req, uri, token, body = nil)
    # req should be an instance of Net::HTTP::<whatever type of request you want>.new
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    req['Authorization'] = "Bearer #{token}"
    req['Content-Type'] = 'text/json'
    req.body = body unless body.nil?
    return https.request(req)
  end

  def list_all_rrsets(zone)
    url = @api + zone + '/rrsets'
    query_api(@token['accessToken'], url)
  end

  def record_exist?(dns_name, all_rrsets)
    dns_name += '.' unless dns_name[-1] == '.'
    return true if all_rrsets['rrSets'].find { |rrset| rrset['ownerName'] == dns_name }
    return false
  end

  def is_ip?(data)
    !!(data   =~ Resolv::IPv4::Regex)
  end

  def sanitize_record(record, zone)
    if record.include?(zone)
      return record.gsub(/#{Regexp.escape(zone)}/, '')[0..-2]
    elsif record.include?(zone[0..-2])
      return record.gsub(/#{Regexp.escape(zone[0..-2])}/, '')[0..-2]
    else
      return record
    end
  end

  def add_records(records_array, zone = 'worldremit.com.')
    # records_array should be an array of hashes with the key being the owner name and the value being the target dns name or IP
    zone += '.' unless zone[-1] == '.'
    all_rrsets = list_all_rrsets(zone)
    records_array.each do |dns_record|
      unless record_exist?(dns_record.keys.first, all_rrsets)
        record = sanitize_record(dns_record.keys.first, zone)
        target_record = dns_record.values.first
        if is_ip?(target_record)
          body = JSON.generate({'ttl' => '300', 'rdata' => [target_record]})
          url = @api + zone + '/rrsets/1/' + record
          @csrelog.debug("Creating an A record for #{record + '.' + zone} - referring to #{target_record}")
          result = post_api(@token['accessToken'], url, body)
          @csrelog.info(result)
        else
          target_record += '.' unless target_record[-1] == '.'
          body = JSON.generate({'ttl' => '300', 'rdata' => [target_record]})
          url = @api + zone + '/rrsets/5/' + record
          @csrelog.debug("Creating a CNAME record for #{record + '.' + zone} - referring to #{target_record}")
          result = post_api(@token['accessToken'], url, body)
          @csrelog.info(result)
        end
      else
        @csrelog.warn("Your record already exists in DNS - #{dns_record.keys.first} -> #{dns_record.values.first}")
      end
    end
  end

end

username = ARGV[0]
password = ARGV[1]
records_array = ARGV[2]
zone = ARGV[3]

unless valid_json?(records_array)
  records_array = JSON.parse(File.read(records_array))
else
  records_array = JSON.parse(records_array)
end


WRUltraDNSManagement.new(username, password).add_records(records_array, zone)

# records_string = '[{"testarecord.worldremit.co.nz": "10.10.10.10"}, {"testcnamerecord.worldremit.co.nz": "mydomain.test.worldremit.co.nz"}]'
# url = 'https://restapi.ultradns.com/v2/zones/worldremit.co.nz/rrsets/1/csre'

# url = 'https://restapi.ultradns.com/v2/zones/worldremit.co.nz/rrsets/5/jenkins2.csre'

# body = JSON.generate({'ttl' => '300', 'rdata' => ['jenkins.mydomain.com.']})

