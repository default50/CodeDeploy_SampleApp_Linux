#!/bin/bash

if which yum &>/dev/null; then
  service httpd stop
elif which apt-get &>/dev/null; then
  service apache2 stop
fi
