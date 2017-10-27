apt-get update
apt-get install -y default-jdk

add-apt-repository ppa:openjdk-r/ppa
apt-get update
apt-get install openjdk-8-jre

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
gem install azure_mgmt_authorization
gem install minitest
gem install minitest-reporters
gem install simplecov
gem install OptionParser
gem install netaddr
gem install git
gem install bundler
gem install json
gem install rest-client


wget https://download.jetbrains.com/teamcity/TeamCity-2017.1.5.tar.gz
  
#tar -xzf TeamCity-10.0.4.tar.gz
tar -xzf TeamCity-2017.1.5.tar.gz

mkdir /opt/JetBrains
mv TeamCity /opt/JetBrains/TeamCity
cd /opt/JetBrains/TeamCity
addgroup teamcity
useradd teamcity -s /bin/bash -m -g teamcity
chown -R teamcity /opt/JetBrains/TeamCity  # Insert Username for $User    


 
#nano /etc/init.d/teamcity
echo '#!/bin/sh' > /etc/init.d/teamcity
echo '### BEGIN INIT INFO' >> /etc/init.d/teamcity
echo '# Provides:          TeamCity autostart' >> /etc/init.d/teamcity
echo '# Required-Start:    $remote_fs $syslog' >> /etc/init.d/teamcity
echo '# Required-Stop:     $remote_fs $syslog' >> /etc/init.d/teamcity
echo '# Default-Start:     2 3 4 5' >> /etc/init.d/teamcity
echo '# Default-Stop:      0 1 6' >> /etc/init.d/teamcity
echo '# Short-Description: Start teamcity daemon at boot time' >> /etc/init.d/teamcity
echo '# Description:       Enable service provided by daemon.' >> /etc/init.d/teamcity
echo '# /etc/init.d/teamcity -  startup script for teamcity' >> /etc/init.d/teamcity
echo '### END INIT INFO' >> /etc/init.d/teamcity
echo ' ' >> /etc/init.d/teamcity
echo ' ' >> /etc/init.d/teamcity
echo '#  Ensure you enter the  right  user name that  TeamCity will run  under' >> /etc/init.d/teamcity
echo 'USER="teamcity"' >> /etc/init.d/teamcity
echo ' ' >> /etc/init.d/teamcity
echo ' ' >> /etc/init.d/teamcity
echo 'export TEAMCITY_DATA_PATH="/opt/JetBrains/TeamCity/.BuildServer"' >> /etc/init.d/teamcity
echo ' ' >> /etc/init.d/teamcity
echo 'case $1 in' >> /etc/init.d/teamcity
echo ' ' >> /etc/init.d/teamcity
echo 'start)' >> /etc/init.d/teamcity
echo '  start-stop-daemon --start  -c $USER --exec /opt/JetBrains/TeamCity/bin/runAll.sh start' >> /etc/init.d/teamcity
echo ' ;;' >> /etc/init.d/teamcity
echo 'stop)' >> /etc/init.d/teamcity
echo '  start-stop-daemon --start -c $USER  --exec  /opt/JetBrains/TeamCity/bin/runAll.sh stop' >> /etc/init.d/teamcity
echo ' ;;' >> /etc/init.d/teamcity
echo ' esac' >> /etc/init.d/teamcity
echo ' ' >> /etc/init.d/teamcity
echo 'exit 0' >> /etc/init.d/teamcity



wget https://xycsrecore01.blob.core.windows.net/bin/sqljdbc_6.2.2.0_enu.tar.gz

gzip -d sqljdbc_6.2.2.0_enu.tar.gz
mkdir /opt/JetBrains/TeamCity/.BuildServer/lib
mkdir /opt/JetBrains/TeamCity/.BuildServer/lib/jdbc
#tar -xzf sqljdbc_6.2.2.0_enu.tar.gz
#mv sqljdbc_6.2.2.0_enu.tar /opt/JetBrains/TeamCity/.BuildServer/lib/jdbc/sqljdbc_6.2.2.0_enu.tar
#cd /opt/JetBrains/TeamCity/.BuildServer/lib/jdbc/
tar -xf sqljdbc_6.2.2.0_enu.tar
cp sqljdbc_6.2/enu/mssql-jdbc-6.2.2.jre8.jar /opt/JetBrains/TeamCity/.BuildServer/lib/jdbc/mssql-jdbc-6.2.2.jre8.jar

chmod +x /etc/init.d/teamcity
update-rc.d teamcity defaults


apt-get -y install nginx

cd /etc/nginx/sites-available
rm default ../sites-enabled/default

touch teamcity
echo 'map $http_upgrade $connection_upgrade {' > teamcity
echo '    default upgrade;' >> teamcity
echo '    ''   '';' >> teamcity
echo '}' >> teamcity
echo '' >> teamcity
echo 'server {' >> teamcity
echo '' >> teamcity
echo '    listen       443;' >> teamcity
echo '    ssl on;' >> teamcity
echo '    ssl_certificate /opt/JetBrains/TeamCity/.ssh/teamcity.csre.worldremit.com.pem;' >> teamcity
echo '    ssl_certificate_key /opt/JetBrains/TeamCity/.ssh/teamcity.csre_private_key.pem;' >> teamcity
echo '    server_name  localhost teamcity.csre.worldremit.com;' >> teamcity
echo '' >> teamcity
echo '    proxy_read_timeout     1200;' >> teamcity
echo '    proxy_connect_timeout  240;' >> teamcity
echo '    client_max_body_size   0;' >> teamcity
echo '' >> teamcity
echo '    location / {' >> teamcity
echo '' >> teamcity
echo '        proxy_pass          http://localhost:8111/;' >> teamcity
echo '        proxy_http_version  1.1;' >> teamcity
echo '        proxy_set_header    X-Forwarded-For $remote_addr;' >> teamcity
echo '        proxy_set_header    X-Forwarded-Host $http_host;' >> teamcity
echo '        proxy_set_header    Host $server_name:$server_port;' >> teamcity
echo '        proxy_set_header    Upgrade $http_upgrade;' >> teamcity
echo '        proxy_set_header    Connection $connection_upgrade;' >> teamcity
echo '    }' >> teamcity
echo '}' >> teamcity

ln -s /etc/nginx/sites-available/teamcity /etc/nginx/sites-enabled/
service nginx restart
