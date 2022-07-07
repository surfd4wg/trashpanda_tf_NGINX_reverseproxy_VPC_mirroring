NGINX reverse proxy

Inbound ports:
* tcp 80/443/22
* udp 4789

Example URL: dashboard.nginx.clientidentifier.redlocust.cloud

# Ex: like this. clientidentifier is the client identifier.
# Place all of these files in the /etc/ directory
# You must run these scripts as root
# First run first script
```
bash nginx-install-prereqs.sh --mysqlpwd password --nginxpwd password --nomfa --installmysql
```
Then run second script, Where clientIdentifier = 'customer name'. ex: acmecorp
```
bash nginx-install-nginx.sh clientidentifier
```
Now navigate to dashboard.nginx.clientidentifier.redlocust.cloud
https://dashboard.nginx.clientidentifier.redlocust.cloud

Default login (username/password): nginxadmin/nginxadmin
