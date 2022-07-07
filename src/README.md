#  ubuntu 18.04 vm and Point a DNS to instance and wait 30secs to propagate

All ports should be open to internet.

dashboard.nginx.clientidentifier.redlocust.cloud

# Ex: like this. clientidentifier is the client identifier.
# Place all of these files in the /etc/ directory
# You must run these scripts as root
# First run first script
bash nginx-install-prereqs.sh --mysqlpwd password --nginxpwd password --nomfa --installmysql

# Then run second script
bash guaca-nginx.sh clientidentifier
# Where clientIdentifier = 'customer name'. ex: acmecorp

Now navigate to dashboard.nginxamole.clientidentifier.redlocust.cloud
dashboard.nginxamole.clientidentifier.redlocust.cloud

Default login (username/password): nginxadmin/nginxadmin