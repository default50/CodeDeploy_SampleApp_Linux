#!/bin/bash

set -x
#exec 3>&1 4>&2 >/tmp/$0.log 2>&1

echo "test"
>&2 echo "error"
#env
#SCRIPTSDIR="$(dirname "$(realpath "$0")")"
#echo -e "\n\n\nDIR=$SCRIPTSDIR\n\n\n"
#su -c "bash -l $SCRIPTSDIR/test2.sh" - ec2-user

#exec 1>&3 2>&4
