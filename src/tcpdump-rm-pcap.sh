#!/bin/bash
# Remove pcap files over 60 minutes old

# Find files created over 60 minutes ago, then delete them
find /var/tmp/*.pcap -amin +60 -print0 | while read -d $'\0' file
do
  basefile=$(basename $file)
  #echo $basefile
  rm $basefile
done
