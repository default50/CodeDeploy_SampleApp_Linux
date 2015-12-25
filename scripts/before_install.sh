#!/bin/bash

if which yum &>/dev/null; then
  yum update -y
  yum install -y httpd
  chkconfig httpd on
elif which apt-get &>/dev/null; then
  if ! dpkg-query -l apache2 | grep -q "^ii"; then
    apt-get update
    apt-get -y upgrade
    apt-get -y install apache2
  fi
fi
