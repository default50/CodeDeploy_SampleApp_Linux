#!/bin/bash

if which yum &>/dev/null; then
  echo "Something to do AfterInstall on yum systems"
elif which apt-get &>/dev/null; then
  echo "Something to do AfterInstall on apt systems"
fi
