#/bin/bash
# Version	1.1
# Date		15.10.2016
# Author 	DerDanilo
defaultsnmpuser=
monitoringhost="None"
hostnamevar=$(hostname -f)
myip=$(hostname -I)

# display usage if the script is not run as root user
        if [[ $USER != "root" ]]; then
            echo "This script must be run as root user!"
            exit 1
		else
			echo "root user detected!!"
        fi
#####################
### Functions
#####################

function confirm () {
# call with a prompt string or use a default
read -r -p "${1:Are you sure? [y/N]}" response
if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]
then
    true
else
    false
fi
}

function check_kernel_os {
if [ "'uname -r | grep ucs'" ]; then
	osisucs="true"
	echo UCS detected: Variable set to true.
	echo UCS unmaintained repos activated
	ucr set  repository/online/unmaintained=yes 
elif [ "'uname -r | grep pve'" ]; then
    osispve="true"
	echo PVE detected: Variable set to true.
elif [ -f "/etc/init.d/psa" ] || [ "'dpkg -l psa | grep psa'" ]; then
    osisplesk="true"
	echo Plesk detected: Variable set to true.
fi
}

function setup-ufw-firewall {
if [ "$osisucs" = "true" ]; then
	echo System runs UCS - Univention, skip ufw setup, add UCR entry
	#ucr set  security/packetfilter/<proto>/[<port>|<port-range>]/all=ACCEPT
	ucr set  security/packetfilter/udp/161/all=ACCEPT
	echo "ucr set  security/packetfilter/udp/161/all=ACCEPT"
	ucr set security/packetfilter/package/snmp/udp/161/all=ACCEPT
	echo "ucr set security/packetfilter/package/snmp/udp/161/all=ACCEPT"
	ucr set security/packetfilter/package/snmp/udp/161/all/en=snmp
	echo "ucr set security/packetfilter/package/snmp/udp/161/en=snmp"
	echo Added UCS firewall rule for snmp
	/etc/init.d/univention-firewall restart
	echo restarted UCS firewall
	echo -e
elif [ "$osispve" = "true" ]; then
	echo "Proxmox has it's own firewall! UFW setup skipped"
elif [ "$osisplesk" = "true" ]; then
	echo "Plesk has it's own firewall! UFW setup skipped"
else
	confirm "Would you like to install ufw firewall and allow only ssh, http, https, snmp? Y|N" && {
	echo Install UFW Firewall and setup rules
	apt-get install ufw -y
	for i in ssh http https snmp ; do ufw allow $i ; done
	yes | ufw enable
	}
	echo -e
fi
}

function install_dependencies {
echo Installing all dependencies....
apt-get update
apt-get install snmp snmpd libsnmp-dev git xinetd -y
apt-get autoremove -y
echo -e
}

function stop_snmpd {
echo Stopping snmpd service
/etc/init.d/snmpd stop
sleep 4
echo -e
}

function change_agentaddress {
echo Have SNMPD listen on all interfaces...
#sed -i 's/original/new/g' file.txt
sed -i '/.*agentAddress.*/c\#agentAddress   STRINGCLEARBYSCRIPT' /etc/snmp/snmpd.conf
echo "agentAddress   udp:161" >> /etc/snmp/snmpd.conf 
echo -e
}

function disable_snmp_v1_and_v2 {
echo Disable SNMP V1 and V2...
#sed -i 's/original/new/g' file.txt
sed -i '/.*rocommunity.*/c\#rocommunity   STRINGCLEARBYSCRIPT' /etc/snmp/snmpd.conf
sed -i '/.*trapsink.*/c\#trapsink   STRINGCLEARBYSCRIPT' /etc/snmp/snmpd.conf
echo -e
}

function set_syslocation {
echo Enter the device location: - SNMP SysLocation
read syslocation
if ! [ -z ${syslocation+x} ]; then 
sed -i 's/.*sysLocation.*/sysLocation    '"$syslocation"'/g' /etc/snmp/snmpd.conf
if [[ 'grep '"$syslocation"' /etc/snmp/snmpd.conf' ]];then
   echo SysLocation set to $syslocation;
   else
   echo Could NOT set SysLocation to $syslocation, please set manually in /etc/snmp/snmpd.conf;
   echo -e
 fi  
fi
echo -e
}

function set_syscontact {
echo Enter E-Mail adress for system contact: - SNMP SysContact
read SysContact
if ! [ -z ${SysContact+x} ]; then 
sed -i 's/.*sysContact.*/sysContact    '"$SysContact"'/g' /etc/snmp/snmpd.conf
if [[ 'grep '"$SysContact"' /etc/snmp/snmpd.conf' ]];then
   echo sysContact set to $SysContact;
   else
   echo Could NOT set sysContact to $SysContact, please set manually in /etc/snmp/snmpd.conf;
   echo -e
 fi  
fi
echo -e
}

function set_SNMPV3_User {
echo Enter SNMPv3 Username:
read defaultsnmpuser
if ! [ -z ${defaultsnmpuser+x} ]; then 
   echo SNMPv3 User set to $defaultsnmpuser;
fi
echo -e
}

function create_snmp_v3_user {
echo Creating SNMP V3 user
echo "net-snmp-create-v3-user -ro -A <Passwort> -X <Encryption Key> -a SHA -x AES <Benutzer>"
passwortsnmp=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 21 | head -n 1)
keysnmp=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 26 | head -n 1)
if net-snmp-create-v3-user -ro -A $passwortsnmp -X $keysnmp -a SHA -x AES $defaultsnmpuser; then
	echo "net-snmp-create-v3-user -ro -A $passwortsnmp -X $keysnmp -a SHA -x AES $defaultsnmpuser"
	else
	net-snmp-config --create-snmpv3-user -ro -A $passwortsnmp -X $keysnmp -a SHA -x AES $defaultsnmpuser
	echo "net-snmp-config --create-snmpv3-user -ro -A $passwortsnmp -X $keysnmp -a SHA -x AES $defaultsnmpuser"
fi
echo -e
}

function clone_librenms_agent {
echo Cloning LibreNMS Agent into /opt/librenms-agent
#Clone the librenms-agent repository:
cd /opt/
git clone https://github.com/librenms/librenms-agent.git /opt/librenms-agent
cd /opt/librenms-agent
echo -e
}

function copy_check_mk_agent_service { 
#Now copy the check_mk_agent:
echo Copying the relevant check_mk_agent
cp /opt/librenms-agent/check_mk_agent /usr/bin/check_mk_agent
echo Correct permission
chmod +x /usr/bin/check_mk_agent
echo -e
}

function copy_service_file_into_place {
#Copy the service file(s) into place.
echo Copying the service files into place
cp /opt/librenms-agent/check_mk_xinetd /etc/xinetd.d/check_mk
echo -e
}

function create_directories {
#Create the relevant directories.
echo Creating the relevant directories
mkdir -p /usr/lib/check_mk_agent/plugins /usr/lib/check_mk_agent/local
echo -e
}

function activate_service_checks {
echo Activating advanced service checks....
echo -e

function check_mysql {
service=$1
if [ -f "/etc/init.d/$service" ]; then
cp /opt/librenms-agent/agent-local/mysql /usr/lib/check_mk_agent/local/
echo MYSQL found: MYSQL checks activated
if [ -f "/etc/mysql/debian.cnf" ]; then
mysqlsysuser=$(grep user /etc/mysql/debian.cnf | head -1 | cut -d"=" -f2 | cut -d" " -f2)
mysqlpassword=$(grep password /etc/mysql/debian.cnf | head -1 | cut -d"=" -f2 | cut -d" " -f2)
cat << EOF > /usr/lib/check_mk_agent/local/mysql.cnf
<?php
\$mysql_user = '$mysqlsysuser';
\$mysql_pass = '$mysqlpassword';
\$mysql_host = 'localhost';
\$mysql_port = 3306;
EOF
echo MYSQL: Sql config written with sysuser
else
cat << EOF > /usr/lib/check_mk_agent/local/mysql.cnf
<?php
\$mysql_user = 'mysqlsysuser';
\$mysql_pass = 'mysqlpassword';
\$mysql_host = 'localhost';
\$mysql_port = 3306;
EOF
echo "MYSQL: Could not configure SQL automatically for LibreNMS agent, please set manually!"
echo "File to configure /usr/lib/check_mk_agent/local/mysql.cnf"
fi
echo -e
fi
}
for i in mysql mysqld ; do check_mysql $i ; done

function check_apache {
service=$1
if [ -f "/etc/init.d/$service" ]; then
    cp /opt/librenms-agent/agent-local/apache /usr/lib/check_mk_agent/local/
	echo APACHE found: APACHE checks activated
fi
}
for i in apache2 apache httpd ; do check_apache $i ; done

service="memcached"
if [ -f "/etc/init.d/$service" ]; then
    cp /opt/librenms-agent/agent-local/memcached /usr/lib/check_mk_agent/local/
	echo MEMCACHED found: MEMCACHED checks activated
fi

service="rrdcached"
if [ -f "/etc/init.d/$service" ]; then
    cp /opt/librenms-agent/agent-local/rrdcached /usr/lib/check_mk_agent/local/
	echo RRDCACHED found: RRDCACHED checks activated
fi

service="ceph"
if [ -f "/etc/init.d/$service" ]; then
    cp /opt/librenms-agent/agent-local/ceph /usr/lib/check_mk_agent/local/
	echo CEPH found: CEPH checks activated
fi

service="nginx"
if [ -f "/etc/init.d/$service" ]; then
    cp /opt/librenms-agent/agent-local/nginx /usr/lib/check_mk_agent/local/
if [ -d "/etc/nginx/conf.d/" ]; then
cat << "EOF" > /etc/nginx/conf.d/monitoring.conf
server {
listen 127.0.0.1:80;
server_name _;
    location /nginx-status {
    stub_status on;
    access_log   off;
    allow 127.0.0.1;
    deny all;
}
}
EOF
else
cat << "EOF" > /etc/nginx/sites-enabled/monitoring.conf
server {
listen 127.0.0.1:80;
server_name _;
    location /nginx-status {
    stub_status on;
    access_log   off;
    allow 127.0.0.1;
    deny all;
}
}
EOF
fi
echo NGINX detected: NGINX checks activated
/etc/init.d/nginx reload
/etc/init.d/nginx restart
fi

function osupdates-check {
echo -e
echo "Copy OS-Updates.sh script..."
cp /opt/librenms-agent/snmp/os-updates.sh /etc/snmp/
echo "Make the script executable"
chmod +x /etc/snmp/os-updates.sh
echo Extend snmp config with os update script... 
cat << "EOF" >> /etc/snmp/snmpd.conf
extend osupdate /etc/snmp/os-updates.sh
EOF
echo Create periodic update check for APT...
cat << "EOF" > /etc/apt/apt.conf.d/10periodic
APT::Periodic::Update-Package-Lists "1";
EOF
echo -e
}

if [ "$osispve" = "true" ]; then
	#cp /opt/librenms-agent/agent-local/proxmox /usr/lib/check_mk_agent/local/
	wget https://github.com/librenms/librenms-agent/blob/master/agent-local/proxmox -O /usr/local/bin/proxmox
	chmod +x /usr/local/proxmox
	echo Extend snmp config with Proxmox script... 
cat << "EOF" >> /etc/snmp/snmpd.conf
extend proxmox /usr/local/bin/proxmox
EOF
	echo PROXMOX detected: PROXMOX checks activated
fi

if ! grep -q \^flags.*\ hypervisor /proc/cpuinfo; then
    cp /opt/librenms-agent/agent-local/temperature /usr/lib/check_mk_agent/local/
	cp /opt/librenms-agent/agent-local/hddtemp /usr/lib/check_mk_agent/local/
	echo Hardware Host detected: HDD and System TEMP checks activated
fi

cp /opt/librenms-agent/agent-local/dpkg /usr/lib/check_mk_agent/local/
echo "DPKG check activated"
}

function correct_agent_script_permission {
echo -e
echo Setting correct permissions to agent scripts...
chmod +x /usr/lib/check_mk_agent/local/*
echo -e
}

function restart_services {
echo Restarting services....
echo Restart xinetd service
/etc/init.d/xinetd restart
echo -e

echo Starting smdpd service
/etc/init.d/snmpd restart
/etc/init.d/snmpd start
echo -e
}

###################################
# Start Script
echo SNMP user:				$defaultsnmpuser
echo SNMP monitor host:		$monitoringhost
echo Hostname: 				$hostnamevar
echo IP Address:			$myip
read -p "Press [ENTER] to start the procedure!"
echo -e

check_kernel_os
setup-ufw-firewall
install_dependencies
stop_snmpd
change_agentaddress
disable_snmp_v1_and_v2

set_syslocation
until confirm "SysLocation correct? - $syslocation - Y|N"
do
set_syslocation
done
confirm="false"

set_syscontact
until confirm "SysContact correct? - $SysContact - Y|N"
do
set_syscontact
done
confirm="false"

if [ -z ${defaultsnmpuser+x} ]; then
   set_SNMPV3_User
   until confirm "SNMPV3 user correct? - $defaultsnmpuser - Y|N"
   do
   set_SNMPV3_User
   done
   confirm="false"
fi


create_snmp_v3_user
clone_librenms_agent
copy_check_mk_agent_service
copy_service_file_into_place
create_directories
activate_service_checks
correct_agent_script_permission
restart_services

############################

echo "##############################################"
echo This machine can now be added to LibreNMS
echo Hostname: 		$hostnamevar
echo IP Address:	$myip
echo Username:		$defaultsnmpuser
echo Password:		$passwortsnmp
echo Key:			$keysnmp
echo Encr.:			authPriv, SHA, AES
if ! [ -z ${syslocation+x} ]; then echo syslocation:	$syslocation; fi
if ! [ -z ${SysContact+x} ]; then echo SysContact:	$SysContact; fi
echo "##############################################"
if [ -f "/etc/init.d/ufw" ]; then
echo Firewall status:
ufw status
fi
echo "##############################################"
echo End of script!


