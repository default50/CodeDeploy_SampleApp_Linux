#!/bin/bash

appname="DemoApplication"
dgname="Demo-ASG-Ubuntu"
zipname="${appname}-${dgname}-$(date -u "+%Y%m%d-%H%M%S").zip"
bucket="default50-public"
bucket_key="CodeDeploy"
configname="CodeDeployDefault.OneAtATime"
profile="code"

aws deploy push --profile ${profile} --application-name ${appname} --s3-location s3://${bucket}/${bucket_key}/${zipname} --ignore-hidden-files --description ${appname}
aws deploy create-deployment --profile ${profile} --application-name ${appname} --deployment-config-name ${configname} --deployment-group-name ${dgname} --s3-location bucket=${bucket},bundleType=zip,key=${bucket_key}/${zipname}
