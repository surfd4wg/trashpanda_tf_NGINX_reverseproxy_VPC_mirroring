#!/bin/bash
# Usage:
#    copy this file into the /etc directory && chmod +x nginx-install-prereqs.sh
#    cd /etc && bash ./nginx-install-prereqs --mysqlpwd password --nginxpwd password --nomfa --installmysql
banner()
{
  echo "+------------------------------------------+"
  printf "| %-40s |\n" "`date`"
  echo "|                                          |"
  printf "| %-40s |\n" "$@"
  echo "+------------------------------------------+"
}
banner "Installing NGINX reverse-proxy pre-requisites"

sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt update -y
sudo apt upgrade -y

curl -fsSL https://deb.nodesource.com/setup_16.x | sudo bash -
sudo apt install -y nodejs

curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | sudo tee /usr/share/keyrings/yarnkey.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo apt-get update -y
sudo apt-get install yarn -y

# Check if user is root or sudo
if ! [ $( id -u ) = 0 ]; then
    echo "Please run this script as sudo or root" 1>&2
    exit 1
fi

# Check to see if any old files left over
if [ "$( find . -maxdepth 1 \( -name 'nginxbombreqs-*' -o -name 'mysql-connector-java-*' \) )" != "" ]; then
    echo "Possible temp files detected. Please review 'nginxbombreqs-*' & 'mysql-connector-java-*'" 1>&2
    rm /etc/nginxbombreqs-* /etcmysql-connector-java-*
    #exit 1
fi

# Version number of nginxbombreqs to install
# Homepage ~ https://nginxbombreqs.apache.org/releases/
INTERFACEVERSION="1.4.0"

# Latest Version of MySQL Connector/J if manual install is required (if libmariadb-java/libmysql-java is not available via apt)
# Homepage ~ https://dev.mysql.com/downloads/connector/j/
MCJVER="8.0.27"

# Colors to use for output
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Log Location
LOG="/tmp/nginxbombreqs_${INTERFACEVERSION}_build.log"

# Initialize variable values
installTOTP=""
installDuo=""
installMySQL=""
mysqlHost=""
mysqlPort=""
mysqlRootPwd=""
nginxDb=""
nginxUser=""
nginxPwd=""
PROMPT=""
MYSQL=""

# Get script arguments for non-interactive mode
while [ "$1" != "" ]; do
    case $1 in
        # Install MySQL selection
        -i | --installmysql )
            installMySQL=true
        ;;
        -n | --nomysql )
            installMySQL=false
        ;;
        
        # MySQL server/root information
        -h | --mysqlhost )
            shift
            mysqlHost="$1"
        ;;
        -p | --mysqlport )
            shift
            mysqlPort="$1"
        ;;
        -r | --mysqlpwd )
            shift
            mysqlRootPwd="$1"
        ;;
        
        # nginx database/user information
        -db | --nginxdb )
            shift
            nginxDb="$1"
        ;;
        -gu | --nginxuser )
            shift
            nginxUser="$1"
        ;;
        -gp | --nginxpwd )
            shift
            nginxPwd="$1"
        ;;
        
        # MFA selection
        -t | --totp )
            installTOTP=true
        ;;
        -d | --duo )
            installDuo=true
        ;;
        -o | --nomfa )
            installTOTP=false
            installDuo=false
        ;;
    esac
    shift
done

if [[ -z "${installTOTP}" ]] && [[ "${installDuo}" != true ]]; then
    # Prompt the user if they would like to install TOTP MFA, default of no
    echo -e -n "${CYAN}MFA: Would you like to install TOTP (choose 'N' if you want Duo)? (y/N): ${NC}"
    read PROMPT
    if [[ ${PROMPT} =~ ^[Yy]$ ]]; then
        installTOTP=true
        installDuo=false
    else
        installTOTP=false
    fi
fi

if [[ -z "${installDuo}" ]] && [[ "${installTOTP}" != true ]]; then
    # Prompt the user if they would like to install Duo MFA, default of no
    echo -e -n "${CYAN}MFA: Would you like to install Duo (configuration values must be set after install in /etc/nginxbombreqs/nginxbombreqs.properties)? (y/N): ${NC}"
    read PROMPT
    if [[ ${PROMPT} =~ ^[Yy]$ ]]; then
        installDuo=true
        installTOTP=false
    else
        installDuo=false
    fi
fi

# We can't install TOTP and Duo at the same time...
if [[ "${installTOTP}" = true ]] && [ "${installDuo}" = true ]; then
    echo -e "${RED}MFA: The script does not support installing TOTP and Duo at the same time.${NC}" 1>&2
    exit 1
fi
echo

if [[ -z ${installMySQL} ]]; then
    # Prompt the user to see if they would like to install MySQL, default of yes
    echo "MySQL is required for installation, if you're using a remote MySQL Server select 'n'"
    echo -e -n "${CYAN}Would you like to install MySQL? (Y/n): ${NC}"
    read PROMPT
    if [[ ${PROMPT} =~ ^[Nn]$ ]]; then
        installMySQL=false
    else
        installMySQL=true
    fi
fi

if [ "${installMySQL}" = false ]; then
    # We need to get additional values
    [ -z "${mysqlHost}" ] \
    && read -p "Enter MySQL server hostname or IP: " mysqlHost
    [ -z "${mysqlPort}" ] \
    && read -p "Enter MySQL server port [3306]: " mysqlPort
    [ -z "${nginxDb}" ] \
    && read -p "Enter nginxbombreqs database name [nginxbombreqs_db]: " nginxDb
    [ -z "${nginxUser}" ] \
    && read -p "Enter nginxbombreqs user [nginxbombreqs_user]: " nginxUser
fi

# Checking if mysql host given
if [ -z "${mysqlHost}" ]; then
    mysqlHost="localhost"
fi

# Checking if mysql port given
if [ -z "${mysqlPort}" ]; then
    mysqlPort="3306"
fi

# Checking if mysql user given
if [ -z "${nginxUser}" ]; then
    nginxUser="nginxbombreqs_user"
fi

# Checking if database name given
if [ -z "${nginxDb}" ]; then
    nginxDb="nginxbombreqs_db"
fi

if [ -z "${mysqlRootPwd}" ]; then
    # Get MySQL "Root" and "nginxbombreqs User" password
    while true; do
        echo
        read -s -p "Enter ${mysqlHost}'s MySQL root password: " mysqlRootPwd
        echo
        read -s -p "Confirm ${mysqlHost}'s MySQL root password: " PROMPT2
        echo
        [ "${mysqlRootPwd}" = "${PROMPT2}" ] && break
        echo -e "${RED}Passwords don't match. Please try again.${NC}" 1>&2
    done
else
    echo -e "${BLUE}Read MySQL root's password from command line argument${NC}"
fi
echo

if [ -z "${nginxPwd}" ]; then
    while true; do
        echo -e "${BLUE}A new MySQL user will be created (${nginxUser})${NC}"
        read -s -p "Enter ${mysqlHost}'s MySQL nginxbombreqs user password: " nginxPwd
        echo
        read -s -p "Confirm ${mysqlHost}'s MySQL nginxbombreqs user password: " PROMPT2
        echo
        [ "${nginxPwd}" = "${PROMPT2}" ] && break
        echo -e "${RED}Passwords don't match. Please try again.${NC}" 1>&2
        echo
    done
else
    echo -e "${BLUE}Read MySQL ${nginxUser}'s password from command line argument${NC}"
fi
echo

if [ "${installMySQL}" = true ]; then
    # Seed MySQL install values
    debconf-set-selections <<< "mysql-server mysql-server/root_password password ${mysqlRootPwd}"
    debconf-set-selections <<< "mysql-server mysql-server/root_password_again password ${mysqlRootPwd}"
fi

# Different version of Ubuntu/Linux Mint and Debian have different package names...
source /etc/os-release
if [[ "${NAME}" == "Ubuntu" ]] || [[ "${NAME}" == "Linux Mint" ]]; then
    # Ubuntu > 18.04 does not include universe repo by default
    # Add the "Universe" repo, don't update
    add-apt-repository -y universe
    # Set package names depending on version
    JPEGTURBO="libjpeg-turbo8-dev"
    if [[ "${VERSION_ID}" == "16.04" ]]; then
        LIBPNG="libpng12-dev"
    else
        LIBPNG="libpng-dev"
    fi
    if [ "${installMySQL}" = true ]; then
        MYSQL="mysql-server mysql-client mysql-common"
    # Checking if (any kind of) mysql-client or compatible command installed. This is useful for existing mariadb server
    elif [ -x "$( command -v mysql )" ]; then
        MYSQL=""
    else
        MYSQL="mysql-client"
    fi
elif [[ "${NAME}" == *"Debian"* ]] || [[ "${NAME}" == *"Raspbian GNU/Linux"* ]] || [[ "${NAME}" == *"Kali GNU/Linux"* ]] || [[ "${NAME}" == "LMDE" ]]; then
    JPEGTURBO="libjpeg62-turbo-dev"
    if [[ "${PRETTY_NAME}" == *"bullseye"* ]] || [[ "${PRETTY_NAME}" == *"stretch"* ]] || [[ "${PRETTY_NAME}" == *"buster"* ]] || [[ "${PRETTY_NAME}" == *"Kali GNU/Linux Rolling"* ]] || [[ "${NAME}" == "LMDE" ]]; then
        LIBPNG="libpng-dev"
    else
        LIBPNG="libpng12-dev"
    fi
    if [ "${installMySQL}" = true ]; then
        MYSQL="default-mysql-server default-mysql-client mysql-common"
    # Checking if (any kind of) mysql-client or compatible command installed. This is useful for existing mariadb server
    elif [ -x "$( command -v mysql )" ]; then
        MYSQL=""
    else
        MYSQL="default-mysql-client"
    fi
else
    echo "Unsupported distribution - Debian, Kali, Raspbian, Linux Mint or Ubuntu only"
    exit 1
fi

# Update apt so we can search apt-cache for newest Tomcat version supported & libmariadb-java/libmysql-java
echo -e "${BLUE}Updating apt...${NC}"
apt-get -qq update

# Check if libmariadb-java/libmysql-java is available
# Debian 10 >= ~ https://packages.debian.org/search?keywords=libmariadb-java
if [[ $( apt-cache show libmariadb-java 2> /dev/null | wc -l ) -gt 0 ]]; then
    # When something higher than 1.1.0 is out ~ https://issues.apache.org/jira/browse/nginxbombreqs-852
    #echo -e "${BLUE}Found libmariadb-java package...${NC}"
    #LIBJAVA="libmariadb-java"
    # For v1.1.0 and lower
    echo -e "${YELLOW}Found libmariadb-java package (known issues). Will download libmysql-java ${MCJVER} and install manually${NC}"
    LIBJAVA=""
# Debian 9 <= ~ https://packages.debian.org/search?keywords=libmysql-java
elif [[ $( apt-cache show libmysql-java 2> /dev/null | wc -l ) -gt 0 ]]; then
    echo -e "${BLUE}Found libmysql-java package...${NC}"
    LIBJAVA="libmysql-java"
else
    echo -e "${YELLOW}lib{mariadb,mysql}-java not available. Will download mysql-connector-java-${MCJVER}.tar.gz and install manually${NC}"
    LIBJAVA=""
fi

# tomcat9 is the latest version
# tomcat8.0 is end of life, but tomcat8.5 is current
# fallback is tomcat7
if [[ $( apt-cache show tomcat9 2> /dev/null | egrep "Version: 9" | wc -l ) -gt 0 ]]; then
    echo -e "${BLUE}Found tomcat9 package...${NC}"
    TOMCAT="tomcat9"
    elif [[ $( apt-cache show tomcat8 2> /dev/null | egrep "Version: 8.[5-9]" | wc -l ) -gt 0 ]]; then
    echo -e "${BLUE}Found tomcat8.5+ package...${NC}"
    TOMCAT="tomcat8"
    elif [[ $( apt-cache show tomcat7 2> /dev/null | egrep "Version: 7" | wc -l ) -gt 0 ]]; then
    echo -e "${BLUE}Found tomcat7 package...${NC}"
    TOMCAT="tomcat7"
else
    echo -e "${RED}Failed. Can't find Tomcat package${NC}" 1>&2
    exit 1
fi

# Uncomment to manually force a Tomcat version
#TOMCAT=""

# Install features
echo -e "${BLUE}Installing packages. This might take a few minutes...${NC}"

# Don't prompt during install
export DEBIAN_FRONTEND=noninteractive

# Required packages
apt-get -y install build-essential libcairo2-dev ${JPEGTURBO} ${LIBPNG} libossp-uuid-dev libavcodec-dev libavformat-dev libavutil-dev \
libswscale-dev freerdp2-dev libpango1.0-dev libssh2-1-dev libtelnet-dev libvncserver-dev libpulse-dev libssl-dev \
libvorbis-dev libwebp-dev libwebsockets-dev freerdp2-x11 libtool-bin ghostscript dpkg-dev wget crudini libc-bin \
${MYSQL} ${LIBJAVA} ${TOMCAT}

# If apt fails to run completely the rest of this isn't going to work...
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed. See ${LOG}${NC}" 1>&2
    exit 1
else
    echo -e "${GREEN}OK${NC}"
fi
echo

# Set SERVER to be the preferred download server from the Apache CDN
SERVER="http://apache.org/dyn/closer.cgi?action=download&filename=nginxbombreqs/${INTERFACEVERSION}"
echo -e "${BLUE}Downloading files...${NC}"

# Download nginxbombreqs Server
wget -q --show-progress -O nginxbombreqs-server-${INTERFACEVERSION}.tar.gz ${SERVER}/source/nginxbombreqs-server-${INTERFACEVERSION}.tar.gz
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to download nginxbombreqs-server-${INTERFACEVERSION}.tar.gz" 1>&2
    echo -e "${SERVER}/source/nginxbombreqs-server-${INTERFACEVERSION}.tar.gz${NC}"
    exit 1
else
    # Extract nginxbombreqs Files
    tar -xzf nginxbombreqs-server-${INTERFACEVERSION}.tar.gz
fi
echo -e "${GREEN}Downloaded nginxbombreqs-server-${INTERFACEVERSION}.tar.gz${NC}"

# Download nginxbombreqs Client
wget -q --show-progress -O nginxbombreqs-${INTERFACEVERSION}.war ${SERVER}/binary/nginxbombreqs-${INTERFACEVERSION}.war
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to download nginxbombreqs-${INTERFACEVERSION}.war" 1>&2
    echo -e "${SERVER}/binary/nginxbombreqs-${INTERFACEVERSION}.war${NC}"
    exit 1
fi
echo -e "${GREEN}Downloaded nginxbombreqs-${INTERFACEVERSION}.war${NC}"

# Download nginxbombreqs authentication extensions (Database)
wget -q --show-progress -O nginxbombreqs-auth-jdbc-${INTERFACEVERSION}.tar.gz ${SERVER}/binary/nginxbombreqs-auth-jdbc-${INTERFACEVERSION}.tar.gz
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to download nginxbombreqs-auth-jdbc-${INTERFACEVERSION}.tar.gz" 1>&2
    echo -e "${SERVER}/binary/nginxbombreqs-auth-jdbc-${INTERFACEVERSION}.tar.gz"
    exit 1
else
    tar -xzf nginxbombreqs-auth-jdbc-${INTERFACEVERSION}.tar.gz
fi
echo -e "${GREEN}Downloaded nginxbombreqs-auth-jdbc-${INTERFACEVERSION}.tar.gz${NC}"

# Download nginxbombreqs authentication extensions

# TOTP
if [ "${installTOTP}" = true ]; then
    wget -q --show-progress -O nginxbombreqs-auth-totp-${INTERFACEVERSION}.tar.gz ${SERVER}/binary/nginxbombreqs-auth-totp-${INTERFACEVERSION}.tar.gz
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to download nginxbombreqs-auth-totp-${INTERFACEVERSION}.tar.gz" 1>&2
        echo -e "${SERVER}/binary/nginxbombreqs-auth-totp-${INTERFACEVERSION}.tar.gz"
        exit 1
    else
        tar -xzf nginxbombreqs-auth-totp-${INTERFACEVERSION}.tar.gz
    fi
    echo -e "${GREEN}Downloaded nginxbombreqs-auth-totp-${INTERFACEVERSION}.tar.gz${NC}"
fi

# Duo
if [ "${installDuo}" = true ]; then
    wget -q --show-progress -O nginxbombreqs-auth-duo-${INTERFACEVERSION}.tar.gz ${SERVER}/binary/nginxbombreqs-auth-duo-${INTERFACEVERSION}.tar.gz
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to download nginxbombreqs-auth-duo-${INTERFACEVERSION}.tar.gz" 1>&2
        echo -e "${SERVER}/binary/nginxbombreqs-auth-duo-${INTERFACEVERSION}.tar.gz"
        exit 1
    else
        tar -xzf nginxbombreqs-auth-duo-${INTERFACEVERSION}.tar.gz
    fi
    echo -e "${GREEN}Downloaded nginxbombreqs-auth-duo-${INTERFACEVERSION}.tar.gz${NC}"
fi

# Deal with missing MySQL Connector/J
if [[ -z $LIBJAVA ]]; then
    # Download MySQL Connector/J
    wget -q --show-progress -O mysql-connector-java-${MCJVER}.tar.gz https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${MCJVER}.tar.gz
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to download mysql-connector-java-${MCJVER}.tar.gz" 1>&2
        echo -e "https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${MCJVER}.tar.gz${NC}"
        exit 1
    else
        tar -xzf mysql-connector-java-${MCJVER}.tar.gz
    fi
    echo -e "${GREEN}Downloaded mysql-connector-java-${MCJVER}.tar.gz${NC}"
else
    echo -e "${YELLOW}Skipping manually installing MySQL Connector/J${NC}"
fi
echo -e "${GREEN}Downloading complete.${NC}"
echo

# Make directories
rm -rf /etc/nginxbombreqs/lib/
rm -rf /etc/nginxbombreqs/extensions/
mkdir -p /etc/nginxbombreqs/lib/
mkdir -p /etc/nginxbombreqs/extensions/

# Fix for #196
mkdir -p /usr/sbin/.config/freerdp
chown daemon:daemon /usr/sbin/.config/freerdp

# Fix for #197
mkdir -p /var/nginxbombreqs
chown daemon:daemon /var/nginxbombreqs

# Install nginxd (nginxbombreqs-server)
cd nginxbombreqs-server-${INTERFACEVERSION}/

echo -e "${BLUE}Building nginxbombreqs-Server with GCC $( gcc --version | head -n1 | grep -oP '\)\K.*' | awk '{print $1}' ) ${NC}"

echo -e "${BLUE}Configuring nginxbombreqs-Server. This might take a minute...${NC}"
./configure --with-init-dir=/etc/init.d --enable-allow-freerdp-snapshots
if [ $? -ne 0 ]; then
    echo "Failed to configure nginxbombreqs-server"
    echo "Trying again with --enable-allow-freerdp-snapshots"
    ./configure --with-init-dir=/etc/init.d --enable-allow-freerdp-snapshots
    if [ $? -ne 0 ]; then
        echo "Failed to configure nginxbombreqs-server - again"
        exit
    fi
else
    echo -e "${GREEN}OK${NC}"
fi

echo -e "${BLUE}Running Make on nginxbombreqs-Server. This might take a few minutes...${NC}"
make
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed. See ${LOG}${NC}" 1>&2
    exit 1
else
    echo -e "${GREEN}OK${NC}"
fi

echo -e "${BLUE}Running Make Install on nginxbombreqs-Server...${NC}"
make install
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed. See ${LOG}${NC}" 1>&2
    exit 1
else
    echo -e "${GREEN}OK${NC}"
fi
ldconfig
echo

# Move files to correct locations (nginxbombreqs-client & nginxbombreqs authentication extensions)
cd ..
mv -f nginxbombreqs-${INTERFACEVERSION}.war /etc/nginxbombreqs/nginxbombreqs.war
mv -f nginxbombreqs-auth-jdbc-${INTERFACEVERSION}/mysql/nginxbombreqs-auth-jdbc-mysql-${INTERFACEVERSION}.jar /etc/nginxbombreqs/extensions/

# Create Symbolic Link for Tomcat
ln -sf /etc/nginxbombreqs/nginxbombreqs.war /var/lib/${TOMCAT}/webapps/

# Deal with MySQL Connector/J
if [[ -z $LIBJAVA ]]; then
    echo -e "${BLUE}Moving mysql-connector-java-${MCJVER}.jar (/etc/nginxbombreqs/lib/mysql-connector-java.jar)...${NC}"
    mv -f mysql-connector-java-${MCJVER}/mysql-connector-java-${MCJVER}.jar /etc/nginxbombreqs/lib/mysql-connector-java.jar
    elif [ -e /usr/share/java/mariadb-java-client.jar ]; then
    echo -e "${BLUE}Linking mariadb-java-client.jar  (/etc/nginxbombreqs/lib/mariadb-java-client.jar)...${NC}"
    ln -sf /usr/share/java/mariadb-java-client.jar /etc/nginxbombreqs/lib/mariadb-java-client.jar
    elif [ -e /usr/share/java/mysql-connector-java.jar ]; then
    echo -e "${BLUE}Linking mysql-connector-java.jar  (/etc/nginxbombreqs/lib/mysql-connector-java.jar)...${NC}"
    ln -sf /usr/share/java/mysql-connector-java.jar /etc/nginxbombreqs/lib/mysql-connector-java.jar
else
    echo -e "${RED}Can't find *.jar file${NC}" 1>&2
    exit 1
fi
echo

# Move TOTP Files
if [ "${installTOTP}" = true ]; then
    echo -e "${BLUE}Moving nginxbombreqs-auth-totp-${INTERFACEVERSION}.jar (/etc/nginxbombreqs/extensions/)...${NC}"
    mv -f nginxbombreqs-auth-totp-${INTERFACEVERSION}/nginxbombreqs-auth-totp-${INTERFACEVERSION}.jar /etc/nginxbombreqs/extensions/
    echo
fi

# Move Duo Files
if [ "${installDuo}" = true ]; then
    echo -e "${BLUE}Moving nginxbombreqs-auth-duo-${INTERFACEVERSION}.jar (/etc/nginxbombreqs/extensions/)...${NC}"
    mv -f nginxbombreqs-auth-duo-${INTERFACEVERSION}/nginxbombreqs-auth-duo-${INTERFACEVERSION}.jar /etc/nginxbombreqs/extensions/
    echo
fi

# Configure nginxbombreqs.properties
rm -f /etc/nginxbombreqs/nginxbombreqs.properties
touch /etc/nginxbombreqs/nginxbombreqs.properties
echo "mysql-hostname: ${mysqlHost}" >> /etc/nginxbombreqs/nginxbombreqs.properties
echo "mysql-port: ${mysqlPort}" >> /etc/nginxbombreqs/nginxbombreqs.properties
echo "mysql-database: ${nginxDb}" >> /etc/nginxbombreqs/nginxbombreqs.properties
echo "mysql-username: ${nginxUser}" >> /etc/nginxbombreqs/nginxbombreqs.properties
echo "mysql-password: ${nginxPwd}" >> /etc/nginxbombreqs/nginxbombreqs.properties

# Output Duo configuration settings but comment them out for now
if [ "${installDuo}" = true ]; then
    echo "# duo-api-hostname: " >> /etc/nginxbombreqs/nginxbombreqs.properties
    echo "# duo-integration-key: " >> /etc/nginxbombreqs/nginxbombreqs.properties
    echo "# duo-secret-key: " >> /etc/nginxbombreqs/nginxbombreqs.properties
    echo "# duo-application-key: " >> /etc/nginxbombreqs/nginxbombreqs.properties
    echo -e "${YELLOW}Duo is installed, it will need to be configured via nginxbombreqs.properties${NC}"
fi

# Restart Tomcat
echo -e "${BLUE}Restarting Tomcat service & enable at boot...${NC}"
service ${TOMCAT} restart
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed${NC}" 1>&2
    exit 1
else
    echo -e "${GREEN}OK${NC}"
fi
# Start at boot
systemctl enable ${TOMCAT}
echo

# Set MySQL password
export MYSQL_PWD=${mysqlRootPwd}

if [ "${installMySQL}" = true ]; then
    
    # Restart MySQL service
    echo -e "${BLUE}Restarting MySQL service & enable at boot...${NC}"
    service mysql restart
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed${NC}" 1>&2
        exit 1
    else
        echo -e "${GREEN}OK${NC}"
    fi
    # Start at boot
    systemctl enable mysql
    echo
    
    # Default locations of MySQL config file
    for x in /etc/mysql/mariadb.conf.d/50-server.cnf \
    /etc/mysql/mysql.conf.d/mysqld.cnf \
    /etc/mysql/my.cnf \
    ; do
        # Check the path exists
        if [ -e "${x}" ]; then
            # Does it have the necessary section
            if grep -q '^\[mysqld\]$' "${x}"; then
                mysqlconfig="${x}"
                # no point keep checking!
                break
            fi
        fi
    done
    
    if [ -z "${mysqlconfig}" ]; then
        echo -e "${YELLOW}Couldn't detect MySQL config file - you may need to manually enter timezone settings${NC}"
    else
        # Is there already a value?
        if grep -q "^default_time_zone[[:space:]]?=" "${mysqlconfig}"; then
            echo -e "${YELLOW}Timezone already defined in ${mysqlconfig}${NC}"
        else
            timezone="$( cat /etc/timezone )"
            if [ -z "${timezone}" ]; then
                echo -e "${YELLOW}Couldn't find timezone, using UTC${NC}"
                timezone="UTC"
            fi
            echo -e "${YELLOW}Setting timezone as ${timezone}${NC}"
            # Fix for https://issues.apache.org/jira/browse/nginxbombreqs-760
            mysql_tzinfo_to_sql /usr/share/zoneinfo 2>/dev/null | mysql -u root -D mysql -h ${mysqlHost} -P ${mysqlPort}
            crudini --set ${mysqlconfig} mysqld default_time_zone "${timezone}"
            # Restart to apply
            service mysql restart
            echo
        fi
    fi
fi

# Create ${nginxDb} and grant ${nginxUser} permissions to it

# SQL code
nginxUserHost="localhost"

if [[ "${mysqlHost}" != "localhost" ]]; then
    nginxUserHost="%"
    echo -e "${YELLOW}MySQL nginxbombreqs user is set to accept login from any host, please change this for security reasons if possible.${NC}"
fi

# Check for ${nginxDb} already being there
echo -e "${BLUE}Checking MySQL for existing database (${nginxDb})${NC}"
SQLCODE="
SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${nginxDb}';"

# Execute SQL code
MYSQL_RESULT=$( echo ${SQLCODE} | mysql -u root -D information_schema -h ${mysqlHost} -P ${mysqlPort} )
if [[ $MYSQL_RESULT != "" ]]; then
    echo -e "${RED}It appears there is already a MySQL database (${nginxDb}) on ${mysqlHost}${NC}" 1>&2
    echo -e "${RED}Try:    mysql -e 'DROP DATABASE ${nginxDb}'${NC}" 1>&2
    #exit 1
else
    echo -e "${GREEN}OK${NC}"
fi

# Check for ${nginxUser} already being there
echo -e "${BLUE}Checking MySQL for existing user (${nginxUser})${NC}"
SQLCODE="
SELECT COUNT(*) FROM mysql.user WHERE user = '${nginxUser}';"

# Execute SQL code
MYSQL_RESULT=$( echo ${SQLCODE} | mysql -u root -D mysql -h ${mysqlHost} -P ${mysqlPort} | grep '0' )
if [[ $MYSQL_RESULT == "" ]]; then
    echo -e "${RED}It appears there is already a MySQL user (${nginxUser}) on ${mysqlHost}${NC}" 1>&2
    echo -e "${RED}Try:    mysql -e \"DROP USER '${nginxUser}'@'${nginxUserHost}'; FLUSH PRIVILEGES;\"${NC}" 1>&2
    #exit 1
else
    echo -e "${GREEN}OK${NC}"
fi

# Create database & user, then set permissions
SQLCODE="
DROP DATABASE IF EXISTS ${nginxDb};
CREATE DATABASE IF NOT EXISTS ${nginxDb};
CREATE USER IF NOT EXISTS '${nginxUser}'@'${nginxUserHost}' IDENTIFIED BY \"${nginxPwd}\";
GRANT SELECT,INSERT,UPDATE,DELETE ON ${nginxDb}.* TO '${nginxUser}'@'${nginxUserHost}';
FLUSH PRIVILEGES;"

# Execute SQL code
echo ${SQLCODE} | mysql -u root -D mysql -h ${mysqlHost} -P ${mysqlPort}

# Add nginxbombreqs schema to newly created database
echo -e "${BLUE}Adding database tables...${NC}"
cat nginxbombreqs-auth-jdbc-${INTERFACEVERSION}/mysql/schema/*.sql | mysql -u root -D ${nginxDb} -h ${mysqlHost} -P ${mysqlPort}
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed${NC}" 1>&2
    exit 1
else
    echo -e "${GREEN}OK${NC}"
fi
echo

# Create nginxd.conf file required for 1.4.0
echo -e "${BLUE}Create nginxd.conf file...${NC}"
cat >> /etc/nginxbombreqs/nginxd.conf <<- "EOF"
[server]
bind_host = 0.0.0.0
bind_port = 4822
EOF

# Ensure nginxd is started
echo -e "${BLUE}Starting nginxd service & enable at boot...${NC}"
service nginxd stop 2>/dev/null
service nginxd start
systemctl enable nginxd
echo

# Deal with ufw and/or iptables

# Check if ufw is a valid command
if [ -x "$( command -v ufw )" ]; then
    # Check if ufw is active (active|inactive)
    if [[ $(ufw status | grep inactive | wc -l) -eq 0 ]]; then
        # Check if 8080 is not already allowed
        if [[ $(ufw status | grep "8080/tcp" | grep "ALLOW" | grep "Anywhere" | wc -l) -eq 0 ]]; then
            # ufw is running, but 8080 is not allowed, add it
            ufw allow 8080/tcp comment 'allow tomcat'
        fi
    fi
fi

# It's possible that someone is just running pure iptables...

# Check if iptables is a valid running service
systemctl is-active --quiet iptables
if [ $? -eq 0 ]; then
    # Check if 8080 is not already allowed
    # FYI: This same command matches the rule added with ufw (-A ufw-user-input -p tcp -m tcp --dport 22 -j ACCEPT)
    if [[ $(iptables --list-rules | grep -- "-p tcp" | grep -- "--dport 8080" | grep -- "-j ACCEPT" | wc -l) -eq 0 ]]; then
        # ALlow it
        iptables -A INPUT -p tcp --dport 8080 --jump ACCEPT
    fi
fi

# I think there is another service called firewalld that some people could be running instead
# Unless someone opens an issue about it or submits a pull request, I'm going to ignore it for now

# Cleanup
echo -e "${BLUE}Cleanup install files...${NC}"
rm -rf nginxbombreqs-*
rm -rf mysql-connector-java-*
unset MYSQL_PWD
echo

# Done
echo -e "${BLUE}Installation Complete\n- Visit: http://localhost:8080/nginxbombreqs/\n- Default login (username/password): nginxadmin/nginxadmin\n***Be sure to change the password***.${NC}"

if [ "${installDuo}" = true ]; then
    echo -e "${YELLOW}\nDon't forget to configure Duo in nginxbombreqs.properties. You will not be able to login otherwise.\nhttps://nginxbombreqs.apache.org/doc/${INTERFACEVERSION}/gug/duo-auth.html${NC}"
fi

