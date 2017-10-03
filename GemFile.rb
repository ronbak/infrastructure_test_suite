source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

gem 'pry-byebug', '3.5.0'
gem 'azure', '0.7.10'
gem 'azure-core', '0.1.12'
gem 'azure_mgmt_resources', '0.12.0'
gem 'azure_mgmt_network', '0.12.0'
gem 'azure_mgmt_storage', '0.12.0'
gem 'azure_mgmt_authorization', '0.12.0'
gem 'minitest'
gem 'minitest-reporters'
gem 'simplecov', '0.15.0'
gem 'OptionParser', '0.5.1'