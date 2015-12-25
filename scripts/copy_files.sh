#!/bin/bash

echo "Copying files..."

cp -rf ./deployment-root/${DEPLOYMENT_GROUP_ID}/${DEPLOYMENT_ID}/deployment-archive/myweb/* /var/www/html

echo "Copying files... Done!"
