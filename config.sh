#!/bin/bash
#

[ $# -eq 0 ] && { echo "usage: config.sh [wireless-device] [internet-device] [AP network name]"; exit 1; }

conf_file="dnsmasq.conf"
hostapd_file="hostapd.conf"
ap_iface=$1
wan_iface=$2
ssid=$3

control_c(){
	echo -e "\e[91mCTRL C Detected!\n"
	echo -e "\e[32m###Killing dnsmasq"
	pkill dnsmasq
	sleep 1
	echo -e "\e[32m###Killing hostapd"
	pkill hostapd
	sleep 1
	iptables --table nat --delete POSTROUTING --out-interface $wan_iface -j MASQUERADE
	iptables --delete FORWARD --in-interface $ap_iface -j ACCEPT
	rm $conf_file $hostapd_file
	ifconfig $ap_iface down
	exit $?
}

trap control_c SIGINT



if ! command -v hostapd &> /dev/null; then
	        sudo apt-get update
		sudo apt-get install -y hostapd
fi


if ! command -v dnsmasq &> /dev/null; then
	        sudo apt-get update
		sudo apt-get install -y dnsmasq
fi

# Configuring hostapd
echo -e "\e[32m###Creating config files"

if [ ! -e "$hostapd_file" ]; then
       cat <<EOL > "$hostapd_file"
interface=$ap_iface
driver=nl80211
ssid=$ssid
hw_mode=g
channel=4
macaddr_acl=0
ignore_broadcast_ssid=0
EOL
fi


if [ -e "$conf_file" ]; then
    echo "El archivo $conf_file ya existe. No es necesario crearlo."
else
        echo "Creando el archivo $conf_file..."
            cat <<EOL > "$conf_file"
interface=$ap_iface
dhcp-range=192.168.2.2,192.168.2.230,255.255.255.0,12h
dhcp-option=3,192.168.2.1
dhcp-option=6,192.168.2.1
server=8.8.8.8
server=8.8.4.4
log-queries
log-dhcp
listen-address=127.0.0.1
listen-address=192.168.2.1

## Cautive Portal
address=/clients1.google.com/192.168.2.1
address=/clients3.google.com/192.168.2.1
address=/connectivitycheck.android.com/192.168.2.1
address=/connectivitycheck.gstatic.com/192.168.2.1
address=/instagram.com/192.168.2.1
address=/facebook.com/192.168.2.1
address=/tiktok.com/192.168.2.1
address=/gmail.com/192.168.2.1
address=/outlook.com/192.168.2.1
address=/netflix.com/192.168.2.1
address=/amazon.com/192.168.2.1
address=/onlyfans.com/192.168.2.1
EOL
      echo "Archivo $conf_file creado con éxito."
 fi



echo -e "\e[32mSetting AP interface"
ifconfig $ap_iface up 192.168.2.1 netmask 255.255.255.0
route add -net 192.168.2.0 netmask 255.255.255.0 gw 192.168.2.1

echo -e "\e[32mSetting internet access"
iptables --table nat --append POSTROUTING --out-interface $wan_iface -j MASQUERADE
iptables --append FORWARD --in-interface $ap_iface -j ACCEPT
sysctl -w net.ipv4.ip_forward=1
echo -e "\e[32mStarting Hostapd"
hostapd $hostapd_file &
dnsmasq -C dnsmasq.conf -d &
echo -e "\e[33mMonitoring\n\n"
tail -f /var/lib/misc/dnsmasq.leases
