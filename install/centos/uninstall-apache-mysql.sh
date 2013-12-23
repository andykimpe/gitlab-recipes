#!/bin/bash
read -e -p "Enter root password of mysql: " password
rm -f /etc/yum.repos.d/PUIAS_6_computational.repo
service gitlab stop
rm -f /etc/init.d/gitlab
rm -rf /usr/local/lib/ruby
rm -rf /usr/lib/ruby
rm -f /usr/local/bin/ruby
rm -f /usr/bin/ruby
rm -f /usr/local/bin/irb
rm -f /usr/bin/irb
rm -f /usr/local/bin/gem
rm -f /usr/bin/gem
userdel git
rm -rf /home/git
rm -f /root/.forward
mysql -u root -p$password -e "DROP DATABASE gitlabhq_production";
