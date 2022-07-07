#!/bin/bash

# Get list of PIDs older than x minutes
ps -e -o pid,etimes,command | grep tcpdump | awk '{if($2>120) print $0}' | awk '{print $1}' > /var/tmp/pidlist.txt

# Kill processes that have been running longer than 2 minutes
filename='/var/tmp/pidlist.txt'
while read line 
do
  echo $line
  kill -9 $line
done < $filename