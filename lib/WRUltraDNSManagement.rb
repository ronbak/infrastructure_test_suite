require 'openssl'
require 'json'
require 'net-http'

class WRUltraDNSManagement

  def initialize()
    @api = "https://restapi.ultradns.com/v2/zones/"
    @token = get_access_token(username, password)
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
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    req = Net::HTTP::Get.new(uri.request_uri)
    req['Authorization'] = "Bearer #{token}"
    res = https.request(req)
    return JSON.parse(res.body)
  end

  def post_api(token, url, body)
    uri = URI(url)
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    req = Net::HTTP::Post.new(uri.request_uri)
    req['Authorization'] = "Bearer #{token}"
    req['Content-Type'] = 'text/json'
    req.body = body
    res = https.request(req)
    return JSON.parse(res.body)
  end

  def put_api(token, url, body)
    uri = URI(url)
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    req = Net::HTTP::Put.new(uri.request_uri)
    req['Authorization'] = "Bearer #{token}"
    req['Content-Type'] = 'text/json'
    req.body = body
    res = https.request(req)
  end

  def list_all_rrsets(zone)
    url = @api + zone + '/rrsets'
    query_api(@token, url)
  end

  def record_exist?(dns_name, all_rrsets)
    dns_name += '.' unless dns_name[-1] == '.'
    return true if all_rrsets['rrSets'].find { |rrset| rrset['ownerName'] == dns_name }
    return false
  end

  
    
    




end

url = 'https://restapi.ultradns.com/v2/zones/worldremit.co.nz/rrsets/1/csre'

url = 'https://restapi.ultradns.com/v2/zones/worldremit.co.nz/rrsets/5/jenkins2.csre'

body = JSON.generate({'ttl' => '300', 'rdata' => ['jenkins.mydomain.com.']})

