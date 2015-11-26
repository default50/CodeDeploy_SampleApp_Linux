#!/bin/bash

set -x
[ -t <&0 ] || exec >> /tmp/test.log

echo "test"
>&2 echo "error"
env
SCRIPTSDIR="$(dirname "$(realpath "$0")")"
echo -e "\n\n\nDIR=$SCRIPTSDIR\n\n\n"
su -c "bash -l $SCRIPTSDIR/test2.sh" - ec2-user
