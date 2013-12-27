#!/bin/bash
# Set custom logging methods so we create a log file in the current working directory.
logfile=/var/log/gitlab-install-mysql-apache.log
exec > >(tee $logfile)
exec 2>&1
passwordgen() {
         l=$1
           [ "$l" == "" ] && l=16
          tr -dc A-Za-z0-9 < /dev/urandom | head -c ${l} | xargs
}
gitlabpassword=`passwordgen`;
if [ -f "/etc/init.d/mysqld" ] ; then
read -e -p "Enter root password of mysql: " password
else
password=`passwordgen`;
fi
echo -e "Enter subdomain for gitlab"
echo -e "eg : gitlab.yourdomain"
read -e -p "Enter subdomain for gitlab : " subdomain
read -e -p "Enter email address for send log file : " emaillog
read -e -p "Enter email address for support : " emailsupport
read -e -p "Enter principal email address for gitlab : " emailgitlab
sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
sudo setenforce 0
sudo chkconfig sendmail off
sudo service sendmail stop
sudo yum -y remove bind-chroot
sudo rpm --import https://www.fedoraproject.org/static/0608B895.txt
sudo yum -y install http://dl.fedoraproject.org/pub/epel/6/$(uname -m)/epel-release-6-8.noarch.rpm
sudo su -c 'cat > "/etc/yum.repos.d/PUIAS_6_computational.repo" <<EOF
[PUIAS_6_computational]
name=PUIAS computational Base \$releasever - \$basearch
mirrorlist=http://puias.math.ias.edu/data/puias/computational/\$releasever/\$basearch/mirrorlist
#baseurl=http://puias.math.ias.edu/data/puias/computational/$releasever/$basearch
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-puias
EOF'
sudo rpm --import http://springdale.math.ias.edu/data/puias/6/x86_64/os/RPM-GPG-KEY-puias
sudo yum-config-manager --enable epel --enable PUIAS_6_computational
sudo yum -y update
sudo yum -y remove ruby ruby-devel ruby-libs rubygem
sudo yum -y groupinstall 'Development Tools'
sudo yum -y install vim-enhanced readline readline-devel ncurses-devel gdbm-devel glibc-devel tcl-devel openssl-devel curl-devel expat-devel db4-devel byacc sqlite-devel gcc-c++ libyaml libyaml-devel libffi libffi-devel libxml2 libxml2-devel libxslt libxslt-devel libicu libicu-devel system-config-firewall-tui python-devel redis sudo wget crontabs logwatch logrotate perl-Time-HiRes git
sudo yum-config-manager --enable rhel-6-server-optional-rpms
sudo yum -y update
sudo chkconfig redis on
sudo service redis start
sudo yum -y install postfix postfix-perl-scripts
sudo useradd -r -u 101 -g mail -d /var/zpanel/vmail -s /sbin/nologin -c "Virtual mailbox" vmail
sudo mkdir -p /var/spool/vacation
sudo useradd -r -d /var/spool/vacation -s /sbin/nologin -c "Virtual vacation" vacation
sudo chmod -R 770 /var/spool/vacation
sudo chown -R vacation:vacation /var/spool/vacation
sudo useradd -r -u 101 -g mail -d /var/mail -s /sbin/nologin -c "Virtual mailbox" vmail
sudo service postfix start
sudo service postfix restart
sudo chkconfig postfix on
sudo yum -y install postgresql-server postgresql-devel mysql mysql-server
#install checkinstall for auto create rpm for ruby
echo "install checkinstall"
cd /tmp
sudo git clone http://checkinstall.izto.org/checkinstall.git
cd checkinstall
sudo make
sudo make install
sudo rm -rf ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
sudo mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
# Download and compile it:
echo "echo compilling ruby"
sudo mkdir /tmp/ruby && cd /tmp/ruby
curl --progress ftp://ftp.ruby-lang.org/pub/ruby/2.0/ruby-2.0.0-p353.tar.gz | tar xz
cd ruby-2.0.0-p353
./configure --prefix=/usr/local/
sudo make
echo "checkinstall ruby please validate default option"
sudo /usr/local/sbin/checkinstall --pkgname=ruby --pkgversion=2.0.0.p353 -y --default --deldoc=yes --deldesc=yes -R make install
cd
sudo rm -rf /tmp/checkinstall
sudo rm -rf /tmp/ruby
echo "install ruby"
sudo yum -y install ~/rpmbuild/RPMS/$(uname -m)/*.rpm
sudo gem install bundler --no-ri --no-rdoc
sudo adduser --system --shell /bin/bash --comment 'GitLab' --create-home --home-dir /home/git/ git
sudo echo $emaillog > /root/.forward
sudo chown root /root/.forward
sudo chmod 600 /root/.forward
sudo restorecon /root/.forward
sudo echo $emaillog > /home/git/.forward
sudo chown git /home/git/.forward
sudo chmod 600 /home/git/.forward
sudo restorecon /home/git/.forward
sudo su git -c "cd /home/git/ && git clone https://github.com/gitlabhq/gitlab-shell.git"
sudo su git -c "cd /home/git/gitlab-shell && git checkout v1.8.0 && cp config.yml.example config.yml"
sudo su git -c "sed -i 's|gitlab_url: \"http://localhost/\"|gitlab_url: \"http://localhost:8080/\"|' /home/git/gitlab-shell/config.yml"
sudo su git -c "/home/git/gitlab-shell/bin/install"
sudo service mysqld start
sudo service mysqld restart
sudo chkconfig mysqld on
sudo mysqladmin -u root password "$password"
sudo mysql -u root -p$password -e "CREATE USER 'gitlab'@'localhost' IDENTIFIED BY '$gitlabpassword'";
sudo mysql -u root -p$password -e "CREATE DATABASE IF NOT EXISTS gitlabhq_production DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci";
sudo mysql -u root -p$password -e "GRANT SELECT, LOCK TABLES, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON gitlabhq_production.* TO gitlab@localhost";
sudo su git -c "cd /home/git/ && git clone https://github.com/gitlabhq/gitlabhq.git gitlab"
sudo su git -c "cd /home/git/gitlab && git checkout 6-3-stable  && cp config/gitlab.yml.example config/gitlab.yml"
sudo su git -c "sed -i 's|email_from: gitlab@localhost|email_from: $emailgitlab|g' /home/git/gitlab/config/gitlab.yml"
sudo su git -c "sed -i 's|support_email: support@localhost|support_email: $emailsupport|g' /home/git/gitlab/config/gitlab.yml"
sudo su git -c "sed -i 's|localhost|$subdomain|g' /home/git/gitlab/config/gitlab.yml"
sudo su git -c "chown -R git /home/git/gitlab/log/"
sudo su git -c "chown -R git /home/git/gitlab/tmp/"
sudo su git -c "chmod -R u+rwX /home/git/gitlab/log/"
sudo su git -c "chmod -R u+rwX /home/git/gitlab/tmp/"
sudo su git -c "mkdir /home/git/gitlab-satellites"
sudo su git -c "mkdir /home/git/gitlab/tmp/pids/"
sudo su git -c "mkdir /home/git/gitlab/tmp/sockets/"
sudo su git -c "chmod -R u+rwX /home/git/gitlab/tmp/pids/"
sudo su git -c "chmod -R u+rwX /home/git/gitlab/tmp/sockets/"
sudo su git -c "mkdir /home/git/gitlab/public/uploads"
sudo su git -c "chmod -R u+rwX /home/git/gitlab/public/uploads"
sudo su git -c "cp /home/git/gitlab/config/unicorn.rb.example /home/git/gitlab/config/unicorn.rb"
sudo git config --global user.name "GitLab"
sudo git config --global user.email "$emailgitlab"
sudo git config --global core.autocrlf input
sudo su git -c "cp /home/git/gitlab/config/database.yml.mysql /home/git/gitlab/config/database.yml"
sudo su git -c "sed -i 's|  password: \"secure password\"|  password: \"$password\"|g' /home/git/gitlab/config/database.yml"
sudo su git -c "chmod o-rwx /home/git/gitlab/config/database.yml"
sudo gem install charlock_holmes --version '0.6.9.4'
sudo gem install json -v '1.7.7'
sudo gem install pg -v '0.15.1'
sudo gem install therubyracer -v '0.11.4'
sudo su git -c "cd /home/git/gitlab/ && bundle install --deployment --without development test mysql puma aws"
sudo su git -c "cd /home/git/gitlab/ && bundle exec rake gitlab:setup RAILS_ENV=production"
sudo wget -O /etc/init.d/gitlab https://raw.github.com/gitlabhq/gitlab-recipes/master/init/sysvinit/centos/gitlab-unicorn
sudo chmod +x /etc/init.d/gitlab
sudo chkconfig --add gitlab
sudo chkconfig gitlab on
sudo su git -c "cd gitlab/ && bundle exec rake gitlab:env:info RAILS_ENV=production"
sudo service gitlab start
sudo su git -c "cd gitlab/ && bundle exec rake gitlab:check RAILS_ENV=production"
sudo yum -y install httpd mod_ssl
sudo chkconfig httpd on
sudo wget -O /etc/httpd/conf.d/gitlab.conf https://raw.github.com/gitlabhq/gitlab-recipes/master/web-server/apache/gitlab.conf
sudo sed -i 's|  ServerName gitlab.example.com|  ServerName $subdomain|g' /etc/httpd/conf.d/gitlab.conf
sudo sed -i 's|    ProxyPassReverse http://gitlab.example.com/|    ProxyPassReverse http://$subdomain/|g' /etc/httpd/conf.d/gitlab.conf
sudo mkdir "/etc/httpd/conf.d.save"
sudo cp "/etc/httpd/conf.d/ssl.conf" "/etc/httpd/conf.d.save"
sudo su -c 'cat > /etc/httpd/conf.d/ssl.conf <<EOF
#NameVirtualHost *:80
<IfModule mod_ssl.c>
    # If you add NameVirtualHost *:443 here, you will also have to change
    # the VirtualHost statement in /etc/httpd/conf.d/gitlab.conf
    # to <VirtualHost *:443>
    #NameVirtualHost *:443
    Listen 443
</IfModule>
EOF'
sudo mkdir -p /var/log/httpd/logs/
sudo service httpd restart
sudo service iptables save
sudo service iptables stop
echo "install file"
echo "url for gitlab http://$subdomain" &>/dev/tty
echo "user (email) admin@local.host" &>/dev/tty
echo "password 5iveL!fe" &>/dev/tty
echo "mysql user gitlab" &>/dev/tty
echo "password for gitlabuser $gitlabpassword" &>/dev/tty
echo "mysql root password $password" &>/dev/tty
echo "information save in /root/gitlab-password.txt" &>/dev/tty
echo url for gitlab http://"$domain" > /root/gitlab-password.txt
echo url for user email "admin@local.host" >> /root/gitlab-password.txt
echo password 5iveL!fe >> /root/gitlab-password.txt
echo password for gitlabuser "$gitlabpassword" >> /root/gitlab-password.txt
echo mysql root password "$password" > /root/gitlab-password.txt
