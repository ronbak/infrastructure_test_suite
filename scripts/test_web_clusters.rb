require 'net/http'
require 'uri'
require 'openssl'

cluster_colour = ARGV[0]

case cluster_colour
when 'blue'
  counter = [51, 52, 54, 55, 56]
when 'green'
  counter = [45, 46, 48, 49]
when 'test'
  counter = [51]
end


counter.each do |octet|
  uri = URI("https://192.168.10.#{octet}")
  https = Net::HTTP.new(uri.host, uri.port)
  https.use_ssl = true
  https.open_timeout = 2
  https.verify_mode = OpenSSL::SSL::VERIFY_NONE
  req = Net::HTTP::Get.new(uri.request_uri)
  req['Host'] = 'www.worldremit.com'
  begin 
    res = https.request(req)
    if res.body.length >= 3500
      puts "Server 192.168.10.#{octet} is up and running"
    else
      puts "\n\n*********************\nit doesn't look good for\n192.168.10.#{octet}\n*********************\n\n#{res.body}\n*********************\n\n"
    end
  rescue Net::OpenTimeout => e
    puts "\nERROR: 192.168.10.#{octet} timed out\n#{e}\n"
  rescue => e
    puts "There was another error check it\n#{e}"
  end
end