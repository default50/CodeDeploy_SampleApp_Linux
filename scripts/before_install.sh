#!/bin/bash

if which yum &>/dev/null; then
  yum update -y
  yum install -y httpd
  chkconfig httpd on
elif which apt-get &>/dev/null; then
  apt-get update
  apt-get -y upgrade
  apt-get -y install apache2
  rm -f /var/www/html/index.html
fi
