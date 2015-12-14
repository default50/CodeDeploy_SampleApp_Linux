#!/bin/bash

if which yum &>/dev/null; then
  echo "yum"
elif which apt-get &>/dev/null; then
  echo "apt-get"
fi

sleep 300
