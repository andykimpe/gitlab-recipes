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
#read -e -p "Enter principal domain of your server : " domain
read -e -p "Enter email address for send log file : " emaillog
read -e -p "Enter email address for support : " emailsupport
read -e -p "Enter principal email address for gitlab : " emailgitlab
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
setenforce 0
chkconfig sendmail off
service sendmail stop
yum -y remove bind-chroot
rpm --import https://www.fedoraproject.org/static/0608B895.txt
yum -y install http://dl.fedoraproject.org/pub/epel/6/$(uname -m)/epel-release-6-8.noarch.rpm
cat > "/etc/yum.repos.d/PUIAS_6_computational.repo" <<EOF
[PUIAS_6_computational]
name=PUIAS computational Base \$releasever - \$basearch
mirrorlist=http://puias.math.ias.edu/data/puias/computational/\$releasever/\$basearch/mirrorlist
#baseurl=http://puias.math.ias.edu/data/puias/computational/$releasever/$basearch
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-puias
EOF
rpm --import http://springdale.math.ias.edu/data/puias/6/x86_64/os/RPM-GPG-KEY-puias
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
service postfix restart
chkconfig postfix on
yum -y install postgresql-server postgresql-devel mysql mysql-server
echo "install ruby repo"
#mkdir /tmp/ruby && cd /tmp/ruby
#curl --progress ftp://ftp.ruby-lang.org/pub/ruby/2.0/ruby-2.0.0-p353.tar.gz | tar xz
#cd ruby-2.0.0-p353
#./configure --prefix=/usr/local/
#make && make install
#cd
#rm -rf /tmp/ruby
cat > "/etc/yum.repos.d/ruby.repo" <<EOF
[RUBY_2_0_0_centos_6]
name=RUBY centos Base \$releasever - \$basearch
baseurl=ftp://ftp.pbone.net/mirror/ftp5.gwdg.de/pub/opensuse/repositories/home:/aredridel/CentOS_CentOS-\$releasever/
enabled=0
gpgcheck=0
EOF
echo "install ruby 2.0"
yum --disablerepo=\* --enablerepo=RUBY_2_0_0_centos_6 -y install ruby ruby-devel ruby-libs rubygem
rm -f /usr/local/bin/ruby
ln -s /usr/bin/ruby /usr/local/bin/ruby
rm -f /usr/local/bin/gem
ln -s /usr/bin/gem /usr/local/bin/gem
gem install bundler --no-ri --no-rdoc
adduser --system --shell /bin/bash --comment 'GitLab' --create-home --home-dir /home/git/ git
echo $emaillog > /root/.forward
chown root /root/.forward
chmod 600 /root/.forward
restorecon /root/.forward
echo $emaillog > /home/git/.forward
chown git /home/git/.forward
chmod 600 /home/git/.forward
restorecon /home/git/.forward
su git -c "cd /home/git/ && git clone https://github.com/gitlabhq/gitlab-shell.git"
su git -c "cd /home/git/gitlab-shell && git checkout v1.8.0 && cp config.yml.example config.yml"
su git -c "sed -i 's|gitlab_url: \"http://localhost/\"|gitlab_url: \"http://localhost:8080/\"|' /home/git/gitlab-shell/config.yml"
su git -c "/home/git/gitlab-shell/bin/install"
service mysqld start
service mysqld restart
chkconfig mysqld on
mysqladmin -u root password "$password"
mysql -u root -p$password -e "CREATE USER 'gitlab'@'localhost' IDENTIFIED BY '$gitlabpassword'";
mysql -u root -p$password -e "CREATE DATABASE IF NOT EXISTS gitlabhq_production DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci";
mysql -u root -p$password -e "GRANT SELECT, LOCK TABLES, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON gitlabhq_production.* TO gitlab@localhost";
su git -c "cd /home/git/ && git clone https://github.com/gitlabhq/gitlabhq.git gitlab"
su git -c "cd /home/git/gitlab && git checkout 6-3-stable"
su git -c 'cat > /home/git/gitlab/config/gitlab.yml <<EOF
# # # # # # # # # # # # # # # # # #
# GitLab application config file  #
# # # # # # # # # # # # # # # # # #
#
# How to use:
# 1. copy file as gitlab.yml
# 2. Replace gitlab -> host with your domain
# 3. Replace gitlab -> email_from

production: &base
  #
  # 1. GitLab app settings
  # ==========================

  ## GitLab settings
  gitlab:
    ## Web server settings
    host: $subdomain
    port: 80
    https: false

    # Uncomment and customize the last line to run in a non-root path
    # WARNING: This feature is known to work, but unsupported
    # Note that three settings need to be changed for this to work.
    # 1) In your application.rb file: config.relative_url_root = "/gitlab"
    # 2) In your gitlab.yml file: relative_url_root: /gitlab
    # 3) In your unicorn.rb: ENV[\'RAILS_RELATIVE_URL_ROOT\'] = "/gitlab"
    #
    # relative_url_root: /gitlab

    # Uncomment and customize if you can\'t use the default user to run GitLab (default: \'git\')
    # user: git

    ## Email settings
    # Email address used in the "From" field in mails sent by GitLab
    email_from: $emailgitlab

    # Email address of your support contact (default: same as email_from)
    support_email: $emailsupport

    ## User settings
    default_projects_limit: 10
    # default_can_create_group: false  # default: true
    # username_changing_enabled: false # default: true - User can change her username/namespace
    ## Default theme
    ##   BASIC  = 1
    ##   MARS   = 2
    ##   MODERN = 3
    ##   GRAY   = 4
    ##   COLOR  = 5
    # default_theme: 2 # default: 2


    ## Users management
    # default: false - Account passwords are not sent via the email if signup is enabled. 
    # signup_enabled: true

    ## Automatic issue closing
    # If a commit message matches this regular expression, all issues referenced from the matched text will be closed.
    # This happens when the commit is pushed or merged into the default branch of a project.
    # When not specified the default issue_closing_pattern as specified below will be used.
    # issue_closing_pattern: ([Cc]lose[sd]|[Ff]ixe[sd]) +#\d+

    ## Default project features settings
    default_projects_features:
      issues: true
      merge_requests: true
      wiki: true
      wall: false
      snippets: false
      public: false

  ## External issues trackers
  issues_tracker:
    # redmine:
    #   title: "Redmine"
    #   ## If not nil, link \'Issues\' on project page will be replaced with this
    #   ## Use placeholders:
    #   ##  :project_id        - GitLab project identifier
    #   ##  :issues_tracker_id - Project Name or Id in external issue tracker
    #   project_url: "http://redmine.sample/projects/:issues_tracker_id"
    #
    #   ## If not nil, links from /#\d/ entities from commit messages will replaced with this
    #   ## Use placeholders:
    #   ##  :project_id        - GitLab project identifier
    #   ##  :issues_tracker_id - Project Name or Id in external issue tracker
    #   ##  :id                - Issue id (from commit messages)
    #   issues_url: "http://redmine.sample/issues/:id"
    #
    #   ## If not nil, linkis to creating new issues will be replaced with this
    #   ## Use placeholders:
    #   ##  :project_id        - GitLab project identifier
    #   ##  :issues_tracker_id - Project Name or Id in external issue tracker
    #   new_issue_url: "http://redmine.sample/projects/:issues_tracker_id/issues/new"
    # 
    # jira:
    #   title: "Atlassian Jira"
    #   project_url: "http://jira.sample/issues/?jql=project=:issues_tracker_id"
    #   issues_url: "http://jira.sample/browse/:id"
    #   new_issue_url: "http://jira.sample/secure/CreateIssue.jspa"

  ## Gravatar
  gravatar:
    enabled: true                 # Use user avatar image from Gravatar.com (default: true)
    # plain_url: "http://..."     # default: http://www.gravatar.com/avatar/%{hash}?s=%{size}&d=mm
    # ssl_url:   "https://..."    # default: https://secure.gravatar.com/avatar/%{hash}?s=%{size}&d=mm

  #
  # 2. Auth settings
  # ==========================

  ## LDAP settings
  ldap:
    enabled: false
    host: \'_your_ldap_server\'
    base: \'_the_base_where_you_search_for_users\'
    port: 636
    uid: \'sAMAccountName\'
    method: \'ssl\' # "ssl" or "plain"
    bind_dn: \'_the_full_dn_of_the_user_you_will_bind_with\'
    password: \'_the_password_of_the_bind_user\'
    allow_username_or_email_login: true

  ## OmniAuth settings
  omniauth:
    # Allow login via Twitter, Google, etc. using OmniAuth providers
    enabled: false

    # CAUTION!
    # This allows users to login without having a user account first (default: false).
    # User accounts will be created automatically when authentication was successful.
    allow_single_sign_on: false
    # Locks down those users until they have been cleared by the admin (default: true).
    block_auto_created_users: true

    ## Auth providers
    # Uncomment the following lines and fill in the data of the auth provider you want to use
    # If your favorite auth provider is not listed you can use others:
    # see https://github.com/gitlabhq/gitlab-public-wiki/wiki/Working-custom-omniauth-provider-configurations
    # The \'app_id\' and \'app_secret\' parameters are always passed as the first two
    # arguments, followed by optional \'args\' which can be either a hash or an array.
    providers:
      # - { name:  \'google_oauth2\', app_id: \'YOUR APP ID\',
      #     app_secret: \'YOUR APP SECRET\',
      #     args: { access_type: \'offline\', approval_prompt: '' } }
      # - { name: \'twitter\', app_id: \'YOUR APP ID\',
      #     app_secret: \'YOUR APP SECRET\'}
      # - { name: \'github\', app_id: \'YOUR APP ID\',
      #     app_secret: \'YOUR APP SECRET\' }



  #
  # 3. Advanced settings
  # ==========================

  # GitLab Satellites
  satellites:
    # Relative paths are relative to Rails.root (default: tmp/repo_satellites/)
    path: /home/git/gitlab-satellites/

  ## Backup settings
  backup:
    path: "tmp/backups"   # Relative paths are relative to Rails.root (default: tmp/backups/)
    # keep_time: 604800   # default: 0 (forever) (in seconds)

  ## GitLab Shell settings
  gitlab_shell:
    # REPOS_PATH MUST NOT BE A SYMLINK!!!
    repos_path: /home/git/repositories/
    hooks_path: /home/git/gitlab-shell/hooks/

    # Git over HTTP
    upload_pack: true
    receive_pack: true

    # If you use non-standard ssh port you need to specify it
    # ssh_port: 22

  ## Git settings
  # CAUTION!
  # Use the default values unless you really know what you are doing
  git:
    bin_path: /usr/bin/git
    # Max size of a git object (e.g. a commit), in bytes
    # This value can be increased if you have very large commits
    max_size: 5242880 # 5.megabytes
    # Git timeout to read a commit, in seconds
    timeout: 10

  #
  # 4. Extra customization
  # ==========================

  extra:
    ## Google analytics. Uncomment if you want it
    # google_analytics_id: \'_your_tracking_id\'

    ## Text under sign-in page (Markdown enabled)
    # sign_in_text: |
    #   ![Company Logo](http://www.companydomain.com/logo.png)
    #   [Learn more about CompanyName](http://www.companydomain.com/)

development:
  <<: *base

test:
  <<: *base
  issues_tracker:
    redmine:
      title: "Redmine"
      project_url: "http://redmine/projects/:issues_tracker_id"
      issues_url: "http://redmine/:project_id/:issues_tracker_id/:id"
      new_issue_url: "http://redmine/projects/:issues_tracker_id/issues/new"

staging:
  <<: *base
EOF'
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
#NameVirtualHost *:80
<IfModule mod_ssl.c>
    # If you add NameVirtualHost *:443 here, you will also have to change
    # the VirtualHost statement in /etc/httpd/conf.d/gitlab.conf
    # to <VirtualHost *:443>
    #NameVirtualHost *:443
    Listen 443
</IfModule>
EOF
mkdir -p /var/log/httpd/logs/
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
echo "mysql root password $password" &>/dev/tty
echo "information save in /root/gitlab-password.txt" &>/dev/tty
echo url for gitlab http://"$domain" > /root/gitlab-password.txt
echo url for user email "admin@local.host" >> /root/gitlab-password.txt
echo password 5iveL!fe >> /root/gitlab-password.txt
echo password for gitlabuser "$gitlabpassword" >> /root/gitlab-password.txt
echo mysql root password "$password" > /root/gitlab-password.txt












