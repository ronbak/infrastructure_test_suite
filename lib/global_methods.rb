require 'json'

def wrmetadata()
  return JSON.parse(File.read("#{File.dirname(__FILE__)}/../metadata/metadata.json"))
end