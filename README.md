# snmp
SNMPV3 Setup Scripts

I wrote those scripts to setup SNMPv3 on Debian based systems within seconds. Nothing fancy, but usefull though.

Works on:
- Debian, detects Plesk
- UCS (Univention)
- Proxmox

Via CLI/SSH enter the following oneliner to execute either script:

#### SNMPv3 Client Setup Script
This one also disabled v1 and v2
bash <(wget -qO- https://raw.githubusercontent.com/DerDanilo/snmp/master/Debian_SNMPV3ClientSetup.sh)


#### SNMPv1 and v2 Disable Script
bash <(wget -qO- https://raw.githubusercontent.com/DerDanilo/snmp/master/Debian_DisableSNMPV1aV2.sh)
