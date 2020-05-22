#!/bin/bash

# Author: CoreyFu

# Purpose:
# Auto configuring a custom wifi router on raspi3b+

# Changelogs:
# Version 0.5
#	- create the shell script
# Version 0.6
#	- add 'apt upgrade' in apt section
#	- add brcm section
#	- add networking section	
#	- modify ipv4_forwarding section 
#	- To resolve dnsmasq.service failed at first time,
#	modify 'bind-interfaces' to 'bind-dynamic' in dnsmasq section
# Version 0.7
#	- delete the section for hostapd and add a new one
#	- modify variables section
#	- modify reboot section to let user consider whether to shutdown the rpi or not


# Variables:
read -p 'Please enter your SSID of this router: ' SSID
read -s -p 'Please enter your Password of this router: ' Passphrase

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
# Creadits to asavah@github.com
# URL: https://github.com/raspberrypi/linux/issues/2619

# Configure as wlan0
interface=wlan0
driver=nl80211

# SSID & Password
ssid=$SSID
wpa_passphrase=$Passphrase

country_code=TW

wpa=2
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP

# Disable MAC filtering
macaddr_acl=0

logger_syslog=0
logger_syslog_level=4
logger_stdout=-1
logger_stdout_level=0

# Mode for 802.11 a/b/g/n/ac
hw_mode=a
wmm_enabled=1

# N
#ieee80211n=1
#require_ht=1
channel=7
#ht_capab=[MAX-AMSDU-3839][HT40+][SHORT-GI-20][SHORT-GI-40][DSSS_CCK-40]

# AC
#ieee80211ac=1
#require_vht=1
#ieee80211d=0
#ieee80211h=0
#vht_capab=[MAX-AMSDU-3839][SHORT-GI-80]
#vht_oper_chwidth=1
#channel=36
#vht_oper_centr_freq_seg0_idx=42
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
# allow ping
-A INPUT -p icmp -j ACCEPT
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

echo 'Reboot in 10 seconds...'
sleep 10
shutdown -r now
