#!/bin/bash
# Send TCP dumps to S3

# ENV vars
BUCKET_NAME="r3d-salt-bucket";
# Get instance id
INSTANCE_ID="`wget -q -O - http://169.254.169.254/latest/meta-data/instance-id`"
# Find files created in the last 10 minutes, and copy them to s3
find /var/tmp/*.pcap -amin -10 -print0 | while read -d $'\0' file
do
  basefile=$(basename $file)
  echo $basefile
  aws s3 cp $file s3://r3d-salt-bucket/${INSTANCE_ID}/$(date +%Y)/$(date +%m)/$(date +%d)/$(date +%H)/${basefile} 
done
