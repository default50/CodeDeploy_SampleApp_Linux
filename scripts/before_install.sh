#!/bin/bash

# Install Apache on Amazon Linux or Ubuntu (only if not previously installed)
if which yum &>/dev/null; then
  yum update -y
  yum install -y httpd
  chkconfig httpd on
elif which apt-get &>/dev/null; then
  if ! dpkg-query -l apache2 | grep -q "^ii"; then
    echo "apache2 not installed, installing!"
    apt-get update
    apt-get -y upgrade
    apt-get -y install apache2
  else
    echo "apache2 already installed, skipping!"
  fi
fi

# Make sure /tmp/myweb doesn't exist so that the test in AfterInstall is really valid
if [ -d /tmp/myweb ]; then
  rm -Rf /tmp/myweb
fi
