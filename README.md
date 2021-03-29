This is a Terraform script that automatically builds an Ubuntu Server in AWS EC2. It also installs various programs through a EC2 user data shell script. The various programs are: -Armor Agent 3.0 -Chrome -Apache2 -xrdp -User + Password for Remote Desktop

Change the ARMOR License Key in the install_user_metadata.sh file.

Rename variables.example to variables.tf, in the same directory as the main.tf file.

The variables in variables.tf must be modified to contain your specific settings. The Armor Agent Key is also in variables.tf.

Once the Machine is running in AWS EC2... you will see the username and password credentials in the /$HOME/rdpcreds.txt file. This user has sudo privileges so !!**** please change your password for this user, the ubuntu user and also the root user ****!!

SSH into the machine using the Public DNS (IPv4) address in the EC2 console, for the instance, and your private key. ssh -i ~/.ssh/.pem Administrator@ec2-X-X-X-X.compute-1.amazonaws.com

If you want to RDP into the machine you will need to install ubuntu desktop. 
https://linuxize.com/post/how-to-install-xrdp-on-ubuntu-20-04/
In that case you will need a machine bigger than t2.micro. You can remote desktop in using the Public DNS (IPv4) address in the EC2 console, for the instance. You will need to download an RDP client. https://docs.microsoft.com/en-us/windows-server/remote/remote-desktop-services/clients/remote-desktop-clients

To tail the Ec2 user data installation log: 
sudo tail -f /var/log/cloud-init-output.log

If the Armor Agent installed correctly, you should see the /opt/armor directory. 

If Apache installs correctly, you should be able to curl localhost.

To change the dimensions of the powershell command window: #Powershell Command Window Size $pshost = get-host $pswindow = $pshost.ui.rawui $newsize = $pswindow.buffersize $newsize.height = 3000 $newsize.width = 200 $pswindow.buffersize = $newsize $newsize = $pswindow.windowsize $newsize.height = 90 $newsize.width = 200 $pswindow.windowsize = $newsize

To grep for processes, ps aux | grep armor

-----
To run this terraform script:
1) Install Terraform v 0.15 or later
2) Download the files into an Ubuntu Linux folder
3) terraform init
4) terraform plan
5) terraform apply
To destroy the same - remove everything from AWS EC2:
6) terraform destroy 


