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
genpassword=`passwordgen`;
gitlabpassword=`passwordgen`;
read -e -p "Enter root password of mysql: " -i $genpassword password
read -e -p "Enter domain or subdomain for gitlab: " domain
read -e -p "Enter email address for send log file: " email
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
setenforce 0
chkconfig sendmail off
service sendmail stop
yum -y remove bind-chroot
wget -O /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-6 https://www.fedoraproject.org/static/0608B895.txt
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-6
yum -y install http://dl.fedoraproject.org/pub/epel/6/$(uname -m)/epel-release-6-8.noarch.rpm
cat /etc/yum.repos.d/PUIAS_6_computational.repo <<EOF
[PUIAS_6_computational]
name=PUIAS computational Base $releasever - $basearch
mirrorlist=http://puias.math.ias.edu/data/puias/computational/$releasever/$basearch/mirrorlist
#baseurl=http://puias.math.ias.edu/data/puias/computational/$releasever/$basearch
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-puias
EOF
wget -O /etc/pki/rpm-gpg/RPM-GPG-KEY-puias http://springdale.math.ias.edu/data/puias/6/x86_64/os/RPM-GPG-KEY-puias
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-puias
yum-config-manager --enable epel --enable PUIAS_6_computational
yum -y update
yum -y groupinstall 'Development Tools'
yum -y install vim-enhanced readline readline-devel ncurses-devel gdbm-devel glibc-devel tcl-devel openssl-devel curl-devel expat-devel db4-devel byacc sqlite-devel gcc-c++ libyaml libyaml-devel libffi libffi-devel libxml2 libxml2-devel libxslt libxslt-devel libicu libicu-devel system-config-firewall-tui python-devel redis sudo wget crontabs logwatch logrotate perl-Time-HiRes git
yum-config-manager --enable rhel-6-server-optional-rpms
yum -y update
chkconfig redis on
service redis start
yum -y install postfix postfix-perl-scripts
useradd -r -u 101 -g mail -d /var/zpanel/vmail -s /sbin/nologin -c "Virtual mailbox" vmail
mkdir -p /var/spool/vacation
useradd -r -d /var/spool/vacation -s /sbin/nologin -c "Virtual vacation" vacation
chmod -R 770 /var/spool/vacation
chown -R vacation:vacation /var/spool/vacation
useradd -r -u 101 -g mail -d /var/mail -s /sbin/nologin -c "Virtual mailbox" vmail
service postfix start
chkconfig postfix on
mkdir /tmp/ruby && cd /tmp/ruby
curl --progress ftp://ftp.ruby-lang.org/pub/ruby/2.0/ruby-2.0.0-p353.tar.gz | tar xz
cd ruby-2.0.0-p353
./configure --prefix=/usr/local/
make && make install
cd
rm -rf /tmp/ruby
gem install bundler --no-ri --no-rdoc
adduser --system --shell /bin/bash --comment 'GitLab' --create-home --home-dir /home/git/ git
echo $email > /root/.forward
chown root /root/.forward
chmod 600 /root/.forward
restorecon /root/.forward
echo $email > /home/git/.forward
chown git /home/git/.forward
chmod 600 /home/git/.forward
restorecon /home/git/.forward
su git -c "cd /home/git/ && git clone https://github.com/gitlabhq/gitlab-shell.git"
su git -c "cd /home/git/gitlab-shell && git checkout v1.8.0 && cp config.yml.example config.yml"
su git -c "sed -i 's|gitlab_url: \"http://localhost/\"|gitlab_url: \"http://$domain/\"|' /home/git/gitlab-shell/config.yml"
su git -c "/home/git/gitlab-shell/bin/install"
yum install -y mysql-server mysql-devel
chkconfig mysqld on
mysqladmin -u root password "$password"
mysql -u root -p$password -e "CREATE USER 'gitlab'@'localhost' IDENTIFIED BY '$gitlabpassword'";
mysql -u root -p$password -e "CREATE DATABASE IF NOT EXISTS gitlabhq_production DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci";
mysql -u root -p$password -e "GRANT SELECT, LOCK TABLES, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON gitlabhq_production.* TO gitlab@localhost";
su git -c "cd /home/git/ && git clone https://github.com/gitlabhq/gitlabhq.git gitlab"
su git -c "cd /home/git/gitlab && git checkout 6-3-stable && cp config/gitlab.yml.example config/gitlab.yml"
su git -c "sed -i 's|localhost|$domain|g' /home/git/gitlab/config/gitlab.yml"
su git -c "chown -R git /home/git/gitlab/log/"
su git -c "chown -R git /home/git/gitlab/tmp/"
su git -c "chmod -R u+rwX /home/git/gitlab/log/"
su git -c "chmod -R u+rwX /home/git/gitlab/tmp/"
su git -c "mkdir /home/git/gitlab-satellites"
su git -c "mkdir /home/git/gitlab/tmp/pids/"
su git -c "mkdir /home/git/gitlab/tmp/sockets/"
su git -c "chmod -R u+rwX /home/git/gitlab/tmp/pids/"
su git -c "chmod -R u+rwX /home/git/gitlab/tmp/sockets/"
su git -c "mkdir /home/git/gitlab/public/uploads"
su git -c "chmod -R u+rwX /home/git/gitlab/public/uploads"
su git -c "cp /home/git/gitlab/config/unicorn.rb.example /home/git/gitlab/config/unicorn.rb"
git config --global user.name "GitLab"
git config --global user.email "gitlab@$domain"
git config --global core.autocrlf input
su git -c "cp /home/git/gitlab/config/database.yml.mysql /home/git/gitlab/config/database.yml"
su git -c "sed -i 's|  password: \"secure password\"|  password:|g' /home/git/gitlab/config/database.yml"
su git -c "sed -i 's|  password:|  password: \"$gitlabpassword\"|g' /home/git/gitlab/config/database.yml"
su git -c "sed -i 's|  username: root|  username: gitlab|g' /home/git/gitlab/config/database.yml"
su git -c "chmod o-rwx /home/git/gitlab/config/database.yml"
gem install charlock_holmes --version '0.6.9.4'
su git -c "cd /home/git/gitlab/ && bundle install --deployment --without development test postgres puma aws"
su git -c "cd /home/git/gitlab/ && bundle exec rake gitlab:setup RAILS_ENV=production"
wget -O /etc/init.d/gitlab https://raw.github.com/gitlabhq/gitlab-recipes/master/init/sysvinit/centos/gitlab-unicorn
chmod +x /etc/init.d/gitlab
chkconfig --add gitlab
chkconfig gitlab on
su git -c "cd gitlab/ && bundle exec rake gitlab:env:info RAILS_ENV=production"
service gitlab start
su git -c "cd gitlab/ && bundle exec rake gitlab:check RAILS_ENV=production"
yum -y install httpd mod_ssl
chkconfig httpd on
wget -O /etc/httpd/conf.d/gitlab.conf https://raw.github.com/gitlabhq/gitlab-recipes/master/web-server/apache/gitlab.conf
sed -i 's|  ServerName gitlab.example.com|  ServerName $domain|g' /etc/httpd/conf.d/gitlab.conf
sed -i 's|    ProxyPassReverse http://gitlab.example.com/|    ProxyPassReverse http://$domain/|g' /etc/httpd/conf.d/gitlab.conf
mkdir "/etc/httpd/conf.d.save"
cp "/etc/httpd/conf.d/ssl.conf" "/etc/httpd/conf.d.save"
cat > /etc/httpd/conf.d/ssl.conf <<EOF
NameVirtualHost *:80
<IfModule mod_ssl.c>
    # If you add NameVirtualHost *:443 here, you will also have to change
    # the VirtualHost statement in /etc/httpd/conf.d/gitlab.conf
    # to <VirtualHost *:443>
    #NameVirtualHost *:443
    Listen 443
</IfModule>
EOF
service httpd restart
lokkit -s http -s https -s ssh
service iptables save
service iptables restart
echo "install fichier"
echo "url for gitlab http://$domain" &>/dev/tty
echo "user (email) admin@local.host" &>/dev/tty
echo "password 5iveL!fe" &>/dev/tty
echo "mysql user gitlab" &>/dev/tty
echo "password for gitlabuser $gitlabpassword" &>/dev/tty
echo "information save in /root/gitlab-password.txt" &>/dev/tty
echo url for gitlab http://"$domain" > /root/gitlab-password.txt
echo url for user (email) "admin@local.host" >> /root/gitlab-password.txt
echo password 5iveL!fe >> /root/gitlab-password.txt
echo password for gitlabuser "$gitlabpassword" >> /root/gitlab-password.txt












