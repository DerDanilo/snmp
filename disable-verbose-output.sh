#/bin/bash

# Debian based
echo "Disable verbose SNMP output - Ignore possible sed errormessages"
sed -i "s|-LS3d|-LS6d|" /etc/default/snmpd
sed -i "s|-LS3d|-LS6d|" /lib/systemd/system/snmpd.service
sed -i "s|-Lsd|-LS6d|" /etc/default/snmpd
sed -i "s|-Lsd|-LS6d|" /lib/systemd/system/snmpd.service
echo "Reload systemd daemon"
systemctl daemon-reload
echo "Restart snmpd"
service snmpd restart
