#!/bin/bash

if which yum &>/dev/null; then
  service httpd start
elif which apt-get &>/dev/null; then
  service apache2 start
fi
