apt-get update
apt-get install -y default-jdk
apt-cache search jdk


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


wget -q -O - https://pkg.jenkins.io/debian/jenkins-ci.org.key | sudo apt-key add -
sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
apt-get update
apt-get install -y jenkins
apt-get -y install nginx

cd /etc/nginx/sites-available
rm default ../sites-enabled/default

touch jenkins
echo 'upstream app_server {' > jenkins
echo '    server 127.0.0.1:8080 fail_timeout=0;' >> jenkins
echo '}' >> jenkins
echo ' ' >> jenkins
echo 'server {' >> jenkins
echo '    listen 443;' >> jenkins
echo '    ssl on;' >> jenkins
echo '    ssl_certificate /var/lib/jenkins/.ssh/csrejenkins.pem;' >> jenkins
echo '    ssl_certificate_key /var/lib/jenkins/.ssh/csrejenkins_private_key.pem;' >> jenkins
echo '    listen [::]:443 default ipv6only=on;' >> jenkins
echo '    server_name csrejenkins.worldremit.com;' >> jenkins
echo ' ' >> jenkins
echo '    location / {' >> jenkins
echo '        proxy_set_header X-Forwarded-Proto https;' >> jenkins
echo '        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;' >> jenkins
echo '        proxy_set_header Host $http_host;' >> jenkins
echo '        proxy_redirect off;' >> jenkins
echo ' ' >> jenkins
echo '        if (!-f $request_filename) {' >> jenkins
echo '            proxy_pass http://app_server;' >> jenkins
echo '            break;' >> jenkins
echo '        }' >> jenkins
echo '    }' >> jenkins
echo '}' >> jenkins
echo '' >> jenkins

ln -s /etc/nginx/sites-available/jenkins /etc/nginx/sites-enabled/
service nginx restart

curl -O https://download.octopusdeploy.com/octopus-tools/4.24.1/OctopusTools.4.24.1.ubuntu.16.04-x64.tar.gz
mkdir /var/lib/octo
tar -xvzf OctopusTools.4.24.1.ubuntu.16.04-x64.tar.gz -C /var/lib/octo/


