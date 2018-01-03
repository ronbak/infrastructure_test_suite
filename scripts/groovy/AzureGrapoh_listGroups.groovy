import groovy.json.*

def urlEncodeMap(aMap){
  def encode = { URLEncoder.encode( "$it".toString() )}
  return aMap.collect { encode(it.key) + '=' + encode(it.value) }.join('&')
}

def httpGet(url, access_token){
  def get = new URL(url).openConnection();
  get.setRequestProperty("Authorization", "Bearer ${access_token}");
  get.setRequestProperty('Accept', 'application/json')
  return get.getInputStream().getText();
}

def getAuthToken(url, client_id, client_secret, resource){
  def post = new URL(url).openConnection();
  message_map = [:]
  message_map.grant_type = 'client_credentials'
  message_map.client_id = client_id
  message_map.client_secret = client_secret
  message_map.resource = resource
  def message_string = urlEncodeMap(message_map)
  post.setRequestMethod("POST")
  post.setDoOutput(true)
  post.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
  post.getOutputStream().write(message_string.getBytes("UTF-8"));
  return post.getInputStream().getText();
}

def tokenResponse = new JsonSlurper().parseText(getAuthToken("https://login.microsoftonline.com/9c59c4ec-cac8-41e7-ba78-3baa0be25172/oauth2/token", '41c29dbb-eaf3-4b0b-9069-24bfb00af65f', '<token>', 'https://graph.windows.net'))

url = "https://graph.windows.net/9c59c4ec-cac8-41e7-ba78-3baa0be25172/groups?api-version=1.6"
response = httpGet(url, tokenResponse.access_token)
x = new JsonSlurper().parseText(response)
groups = []

x.value.each{
  if(it.securityEnabled == true){
    groups << it.displayName
  }
}

while(x.'odata.nextLink') {
  link = x.'odata.nextLink'.split('skiptoken=X')[-1]
  new_url = "${url}&\$skiptoken=X${link}"
  x = new JsonSlurper().parseText(httpGet(new_url, tokenResponse.access_token))
  x.value.each{
    if(it.securityEnabled == true){
      groups << it.displayName
    }
  }
}

println groups.size
