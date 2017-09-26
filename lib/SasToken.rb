require 'cgi'
require 'base64'
require 'openssl'

# The SASToken class abstractly represents a Shared Access Signature token.
class SasToken
  # The string token generated.
  attr_reader :token
  # Generate and return an SasToken object.
  #
  # token = SasToken.new('http://yourexamplenamespace', 'some-policy', 'xxxyyyzzz')
  #
  # Parameters:
  #
  # * url         - The resource identifier you're accessing.
  # * key_name    - The policy/authorization rule for the given access_key.
  # * access_key  - The policy's secret key.
  # * lifetime    - The lifetime (expire) of the token in minutes. The default is 1 hour.
  # * digest_type - The type of OpenSSL::Digest to use. The default is sha256.
  #
  def initialize(url, access_key, lifetime = 60, digest_type = 'sha256')
    target_uri = url.downcase
    t = Time.now.utc + lifetime*60
    start_time = Time.now.utc.to_s.gsub('UTC', '').strip.gsub(' ', 'T') << 'Z'
    expires = t.to_s.gsub('UTC', '').strip.gsub(' ', 'T') << 'Z'
    to_sign = "#{target_uri}\n#{expires}"
    signature = CGI.escape(
      Base64.strict_encode64(
        OpenSSL::HMAC.digest(
          OpenSSL::Digest.new(digest_type), access_key, to_sign
        )
      )
    )
    @token = "?sv=2017-04-17&ss=b&srt=sco&sp=r&se=#{expires}&st=#{start_time}&spr=https&sig=#{signature}"
  end
  # Returns the SasToken object as a string.
  def to_s
    @token
  end
  # Returns the SasToken object as a string.
  def to_str
    @token
  end
end # SasToken

lifetime = 10
digest_type = 'sha256'
url = 'https://csresa1sadevwr.blob.core.windows.net/templates/nsgs.json'
access_key = 'pMgnfgYMiHYNTUAop8D0yYOFeBLQaQyvop+IOagSa9JnU3Uoum0yCtAM3vod5ooXzEa2GUhZBdX+QBFk9Ur6og=='


https://csresa1sadevwr.blob.core.windows.net/arm-templates/vnets_subnets.json/?sv=2017-04-17&ss=b&srt=o&sp=r&se=2017-09-25T21:05:58Z&st=2017-09-25T13:05:58Z&spr=https&sig=uPd4ppttIQLN6KethqoXa5vQ7Gghq2NW5jLXwj0WcUI%3D


signer = Azure::Storage::Core::Auth::SharedAccessSignatureSigner.new 'csresa1devwr', nil
blob_client = Azure::Storage::Blob::BlobService.new(signer: signer)
blob_properties = blob_client.get_blob_properties container_name, blob_name


"https://csresa1sadevwr.blob.core.windows.net/templates/nsgs.json?sv=2017-04-17&ss=b&srt=sco&sp=r&se=2017-09-25T21:23:25Z&st=2017-09-25T11:23:25Z&spr=https&sig=uFOz%2BKnK68YSb5cs4r49HhigWf%2B8ZUy167DgEHT1GrM%3D"

"https://csresa1sadevwr.blob.core.windows.net/templates/nsgs.json?sv=2017-04-17&ss=b&srt=sco&sp=r&se=2017-09-25T12:43:13Z&st=2017-09-25T12:33:13Z&spr=https&sig=G7I32wPV%2F74WGocZlb4%2BKougY4h4EC2MtHcaKj7o7YE%3D"
 "https://csresa1sadevwr.blob.core.windows.net/templates/nsgs.json?sp=rl&sv=2016-05-31&sr=c&se=2017-09-25T13%3A37%3A28Z&sig=yN15PzmM56hVyz1MWCHZCrrE0wtQGatguHIaUkEMx94%3D"

Azure::Storage.new
account_name = Azure::Storage.storage_account_name, access_key = Azure::Storage.storage_access_key

signer = Azure::Storage::Core::Auth::SharedAccessSignature.new(Azure::Storage.storage_account_name, Azure::Storage.storage_access_key)
options = {service: 'b', resource: 'b', permissions: 'rl'}
path = 'https://csresa1devwr.blob.core.windows.net/templates/nsgs.json'
signer.generate_service_sas_token(path, options)

options = {service: 'b', resource: 'sco', permissions: 'rwdla', start: "2017-09-25T13:28:10Z", expiry: "2017-09-25T23:28:10Z", protocol: 'HTTPS'}
signer.generate_account_sas_token(options)
curl "https://csresa1sadevwr.blob.core.windows.net/templates/nsgs.json?sp=rwdla&sv=2016-05-31&ss=b&srt=sco&st=2017-09-25T13%3A28%3A10Z&se=2017-09-25T23%3A28%3A10Z&spr=HTTPS&sig=okk%2FDn9qBRO4JCvTtEmcsVBfBww5QEzuJkeVi7fth5E%3D"



curl "https://csresa1sadevwr.blob.core.windows.net/templates/nsgs.json?sp=rwdla&sv=2016-05-31&ss=b&srt=sco&se=2017-09-25T13%3A54%3A07Z&sig=96PfeyZ%2FDijMDGHP%2BvkCnP%2FM2qA2Tb%2BkPniPx0xk04k%3D"

uri = URI('https://csresa1sadevwr.blob.core.windows.net/templates/nsgs.json')
signer.signed_uri(uri, true, {service: 'b', resource: 'sco'})
curl "https://csresa1sadevwr.blob.core.windows.net/templates/nsgs.json?sp=r&sv=2016-05-31&ss=b&srt=sco&se=2017-09-25T13%3A50%3A44Z&sig=r16dbUZEzb6V6xPimV3ueKpdpolVKMzZXlwp1kGONTw%3D"