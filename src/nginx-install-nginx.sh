#!/bin/bash
# Usage:
#    copy this file into the /etc directory && chmod +x nginx-install-nginx.sh
#    cd /etc && bash ./nginx-install-nginx.sh clientIdentifier 
#    for example: clientIdentifier may be the company name such as "acmecorp"
# Note:
#    This script was built for an DNS name that belongs to the AWS hosted zone redlocust.cloud.
#    Create your own dns hosted zone in your AWS account, for your own domain and replace redlocust.cloud in the script with it
banner()
{
  echo "+------------------------------------------+"
  printf "| %-40s |\n" "`date`"
  echo "|                                          |"
  printf "| %-40s |\n" "$@"
  echo "+------------------------------------------+"
}
banner "Installing NGINX with reverse-proxy"

if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters. Client Identifier is required."
    exit 1
fi

sudo apt update -y

sudo apt install nginx -y

sudo systemctl start nginx

sudo systemctl reload nginx

sudo systemctl enable nginx

sudo apt install certbot python3-certbot-nginx -y


#chek if file exists
if [ -f "nginx.conf" ]; then
    echo "nginx.conf File exists."
else
    echo "nginx.conf File does not exist."
    exit 1
fi

#move file
sudo mv -f nginx.conf /etc/nginx/
sleep 1
chmod 644 /etc/nginx/nginx.conf

sleep 2

sudo systemctl restart nginx

sleep 2



echo "prefix is : $1"


#rename file name "dashboard.nginx.XXXX.redlocust.cloud" to "dashboard.nginx.$1.redlocust.cloud"
cp guaca.nginx.conf dashboard.nginx.$1.redlocust.cloud
#check above command if it works
if [ $? -eq 0 ]; then
    echo OK
else
    echo FAIL
fi


#check if file exists
if [ -f "dashboard.nginx.$1.redlocust.cloud" ]; then
    echo "dashboard.nginx.$1.redlocust.cloud File exists."
else
    echo "dashboard.nginx.$1.redlocust.cloud File does not exist."
    exit 1
fi

#replace "XXXX" with client identifier
sed -i "s/XXXX/$1/g" dashboard.nginx.$1.redlocust.cloud

echo ls -al

cat dashboard.nginx.$1.redlocust.cloud

rm /etc/nginx/sites-enabled/default

sudo mv dashboard.nginx.$1.redlocust.cloud /etc/nginx/sites-enabled/


sudo certbot --noninteractive --agree-tos --register-unsafely-without-email --redirect --nginx -d dashboard.nginx.$1.redlocust.cloud





sudo systemctl status certbot.timer

sleep 2

sudo systemctl reload nginx

sleep 2

sudo systemctl restart nginx


