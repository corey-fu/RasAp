#!/bin/bash

# Author: CoreyFu

# Purpose:
# Auto configuring a custom wifi router on raspi3b+

# Changelogs:
# Version 0.5
#	- create the shell script
# Version 0.6
#	- append 'apt upgrade' in apt section
#	- append brcm section
#	- append networking section	
#	- modify ipv4_forwarding section 
#	- To resolve dnsmasq.service failed at first time,
#	modify 'bind-interfaces' to 'bind-dynamic' in dnsmasq section


# Variables:
SSID=
Passphrase=

#echo 'Modifly the User PATH...'
#cat >> /home/admin/.bashrc << EOF
#
## Configure PATH
#export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
#
#EOF


echo 'Install required packages...'
apt update -y && apt upgrade -y && \
       	apt install -y dhcpcd5 dnsmasq hostapd iw net-tools resolvconf wget

echo 'Stop services...'
systemctl stop dhcpcd
systemctl stop dnsmasq
systemctl unmask hostapd
systemctl stop hostapd

#echo 'Modprobe brcmfmac...'
#wget https://github.com/RPi-Distro/firmware-nonfree/raw/master/brcm/brcmfmac43455-sdio.clm_blob -P /lib/firmware/brcm/
#modprobe -r brcmfmac
#modprobe brcmfmac

echo 'Write the custom cofig to networking...'
cat >> /etc/network/interfaces << EOF

auto lo
iface lo inet loopback

auto eth0
allow-hotplug eth0
iface eth0 inet dhcp
EOF

echo 'Write the custom cofig to dhcpcd...'
mv /etc/dhcpcd.conf /etc/dhcpcd.orig
cat > /etc/dhcpcd.conf << EOF
# Credits to https://github.com/billz/raspap-webgui
hostname 
clientid 
persistent 
option rapid_commit 
option domain_name_servers, domain_name, domain_search, host_name 
option classless_static_routes 
option ntp_servers 
require dhcp_server_identifier 
slaac private 
nohook lookup-hostname 

# Wlan0 configuration 
interface wlan0 
static ip_address=192.168.80.1/24 
static routers=192.168.80.1 
static domain_name_server=8.8.8.8 8.8.4.4 

# Uap0 configuration 
interface uap0 
static ip_address=192.168.90.1/24 
nohook wpa_supplicant
EOF

echo 'Write the custom cofig to dnsmasq...'
mv /etc/dnsmasq.orig /etc/dnsmasq.conf
cat > /etc/dnsmasq.conf << EOF
# Use waln0 interface
interface=wlan0
# Binds the address of individual interfaces
bind-dynamic
# Leaving only DHCP and/or TFTP.
port=53
# Never forward plain names (without a dot or domain part)
domain-needed
# Never forward addresses in the non-routed address spaces.
bogus-priv
# Use /etc/resolv.conf to resolv upstream dns server
#resolv-file=/etc/resolv_dnsmasq.conf
# Reject /etc/hosts
#no-hosts
# Forward DNS requests to Google DNS
server=8.8.8.8


# Configure domain name
#domain=example.com
# Expands the hostnames to the domain value
# For example: 192.168.20.102 host102.my.com
expand-hosts


# For DNS reverse mapping
#ptr-record=254.0.25.172.in-addr.arpa,dns.my.com


# Configure defalut router which in client is gateway
dhcp-option=option:router,192.168.80.1
# Set the range of ip addresses
dhcp-range=192.168.80.100,192.168.80.150,12h
# Assign a ip address for the client
#dhcp-host=MAC,192.168.80.20
EOF

echo 'Write the custom cofig to hostapd...'
mv /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.orig
cat > /etc/hostapd/hostapd.conf << EOF
# Credits to https://github.com/billz/raspap-webgui
driver=nl80211
ctrl_interface=/var/run/hostapd
ctrl_interface_group=0
beacon_int=100
auth_algs=1
wpa_key_mgmt=WPA-PSK
ssid=$SSID
channel=7
hw_mode=g
wpa_passphrase=$Passphrase
interface=wlan0
wpa=2
wpa_pairwise=CCMP
country_code=
## Rapberry Pi 3 specific to on board WLAN/WiFi
ieee80211n=1 # 802.11n support (Raspberry Pi 3)
wmm_enabled=1 # QoS support (Raspberry Pi 3)
ht_capab=[HT40][SHORT-GI-20][DSSS_CCK-40] # (Raspberry Pi 3)
EOF

echo 'Enable ipv4 forwarding...'
sed -i 's/\#net\.ipv4\.ip\_forward\=1/net\.ipv4\.ip\_forward\=1/g' /etc/sysctl.conf

#echo 'Enable ipv4 forwarding immeadly...'
#echo '1' > /proc/sys/net/ipv4/ip_forward

echo 'Configure NAT...'
mv /etc/iptables/rules.v4 /etc/iptables/rules.v4.orig
cat > /etc/iptables/rules.v4 << EOF
#Credits to https://gridscale.io/en/community/tutorials/debian-router-gateway/
*nat
-A POSTROUTING -o eth0 -j MASQUERADE
COMMIT

*filter
-A INPUT -i lo -j ACCEPT
# allow ssh, so that we do not lock ourselves
-A INPUT -i eth0 -p tcp -m tcp --dport 22 -j ACCEPT
# allow incoming traffic to the outgoing connections,
# et al for clients from the private network
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
# prohibit everything else incoming
-A INPUT -i eth0 -j DROP
COMMIT
EOF

echo 'Enable services...'
systemctl enable dhcpcd 
systemctl enable dnsmasq 
systemctl enable hostapd

#systemctl restart dhcpcd 
#systemctl restart dnsmasq 
#systemctl restart hostapd

echo 'Reboot...'
shutdown -r now
