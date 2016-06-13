#! /bin/bash

time=3

echo "TEST: I will now sleep ${time}s to pretend I'm doing something useful!"
sleep ${time}
echo "Done sleeping, resuming!"

echo "This is the ENV for this script!"
env
