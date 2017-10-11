apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
echo "deb http://download.mono-project.com/repo/ubuntu xenial main" | tee /etc/apt/sources.list.d/mono-official.list
apt-get update
apt-get install -y libxml2-dev libxslt1-dev zlib1g-dev liblzma-dev mono-complete ruby-full
gem install pry-byebug -v 3.5.0
gem install azure
gem install azure-core
gem install azure_mgmt_resources
gem install azure_mgmt_network
gem install azure_mgmt_storage
gem install azure_mgmt_policy
gem install minitest
gem install minitest-reporters
gem install simplecov
gem install OptionParser