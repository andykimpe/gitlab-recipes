#!/bin/bash
passwordgen() {
         l=$1
           [ "$l" == "" ] && l=16
          tr -dc A-Za-z0-9 < /dev/urandom | head -c ${l} | xargs
}
genpassword=`passwordgen`;
read -e -p "Enter root password of mysql: " -i $genpassword password
read -e -p "Enter domain or subdomain for gitlab: " domain
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
