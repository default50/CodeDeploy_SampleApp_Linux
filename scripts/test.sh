#!/bin/sh

set -x

echo "test"
env
SCRIPTSDIR="$(dirname "$(realpath "$0")")"
echo -e "\n\n\nDIR=$SCRIPTSDIR\n\n\n"
su -c "bash -l $SCRIPTSDIR/test2.sh" - ec2-user
