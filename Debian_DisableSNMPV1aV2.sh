#/bin/bash
# Version	1.0
# Date		01.07.2016
# Author 	DerDanilo

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

function start_snmpd {
echo Stopping snmpd service
/etc/init.d/snmpd start
sleep 2
echo -e
}

function test_snmpv1av2 {
echo Test SNMP V1 and V2 - Should be "Timeout: No Response from localhost"
echo Testing V1....
snmpwalk -v1 -c public localhost
echo Testing V2C....
snmpwalk -v2c -c public localhost
echo -e
}

stop_snmpd
change_agentaddress
disable_snmp_v1_and_v2
start_snmpd
test_snmpv1av2
echo Done!
