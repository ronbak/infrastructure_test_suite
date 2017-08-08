require 'json'
require 'uri'

def wrmetadata()
  return JSON.parse(File.read("#{File.dirname(__FILE__)}/../metadata/metadata.json"))
end

def valid_json?(json)
  begin
    JSON.parse(json)
    return true
  rescue
  end
  return false
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