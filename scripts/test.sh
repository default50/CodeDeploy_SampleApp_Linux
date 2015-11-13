#!/bin/sh

echo "test"
env
SCRIPTSDIR="$(dirname "$(realpath "$0")")"
echo -e "\n\n\nDIR=$SCRIPTSDIR\n\n\n"
bash -l $SCRIPTSDIR/test2.sh
