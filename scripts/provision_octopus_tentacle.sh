#!/bin/bash
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
echo "deb http://download.mono-project.com/repo/ubuntu xenial main" | tee /etc/apt/sources.list.d/mono-official.list
apt-get update
apt-get install -y mono-complete
apt-get install -y libxml2-dev libxslt1-dev zlib1g-dev liblzma-dev
apt-get install -y ruby-full
gem install pry-byebug -v 3.5.0
gem install azure -v 0.7.10
gem install azure-core -v 0.1.12
gem install azure_mgmt_resources -v 0.12.0
gem install azure_mgmt_network -v 0.12.0
gem install azure_mgmt_storage -v 0.12.0
gem install minitest
gem install minitest-reporters
gem install simplecov -v 0.15.0
gem install OptionParser -v 0.5.1
