#!/bin/bash -e

# github.com/jawj/wireguard-setup
# Copyright (c) 2025 George MacKerron
# Released under the MIT licence: http://opensource.org/licenses/mit-license

# INSTALL PACKAGES

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y wireguard apt-utils dnsutils language-pack-en iptables-persistent unattended-upgrades qrencode

# GATHER INFO

ETH0=$(ip route get 1.1.1.1 | grep -oP ' dev \K\S+')
echo "Network interface: ${ETH0}"

IPV4=$(dig -4 +short myip.opendns.com @resolver1.opendns.com)
echo "External IPv4: ${IPV4}"

IPV4POOL="10.102"
echo -n "${IPV4POOL}" > /etc/wireguard/ipv4pool
echo "IPv4 pool: ${IPV4POOL}.0.0/16"

read -r -p "Timezone (default: Europe/London): " TZONE
TZONE=${TZONE:-'Europe/London'}

read -r -p "Desired Wireguard port (default: 51820): " WGPORT
WGPORT=${WGPORT:-51820}

read -r -p "Desired SSH log-in port (default: 22): " SSHPORT
SSHPORT=${SSHPORT:-22}

# SET UP SYSTEM

apt-get upgrade -y

timedatectl set-timezone "${TZONE}"
/usr/sbin/update-locale LANG=en_GB.UTF-8

sed -r \
-e 's|^//Unattended-Upgrade::MinimalSteps "true";$|Unattended-Upgrade::MinimalSteps "true";|' \
-e 's|^//Unattended-Upgrade::Automatic-Reboot "false";$|Unattended-Upgrade::Automatic-Reboot "true";|' \
-e 's|^//Unattended-Upgrade::Remove-Unused-Dependencies "false";|Unattended-Upgrade::Remove-Unused-Dependencies "true";|' \
-e 's|^//Unattended-Upgrade::Automatic-Reboot-Time "02:00";$|Unattended-Upgrade::Automatic-Reboot-Time "03:00";|' \
-i /etc/apt/apt.conf.d/50unattended-upgrades

echo 'APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
' > /etc/apt/apt.conf.d/10periodic

service unattended-upgrades restart

sed -r \
-e "s/^#?Port [0-9]+$/Port ${SSHPORT}/" \
-i.original /etc/ssh/sshd_config

service ssh restart

# FIREWALL

iptables  -P INPUT   ACCEPT
iptables  -P FORWARD ACCEPT
iptables  -P OUTPUT  ACCEPT

iptables  -F
iptables  -t nat -F

# accept anything already accepted
iptables  -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# accept anything on the loopback interface
iptables  -A INPUT -i lo -j ACCEPT

# drop invalid packets
iptables  -A INPUT -m state --state INVALID -j DROP

# rate-limit repeated new requests from same IP to any ports
iptables  -I INPUT -i "${ETH0}" -m state --state NEW -m recent --set
iptables  -I INPUT -i "${ETH0}" -m state --state NEW -m recent --update --seconds 300 --hitcount 60 -j DROP

# accept SSH
iptables  -A INPUT -p tcp --dport "${SSHPORT}" -j ACCEPT
iptables  -A INPUT -p udp --dport "${WGPORT}" -i "${ETH0}" -j ACCEPT

# forward Wireguard traffic
iptables  -A FORWARD -i "${ETH0}" -o wg0 -d "${IPV4POOL}.0.0/16" -j ACCEPT
iptables  -A FORWARD -i wg0 -o "${ETH0}" -s "${IPV4POOL}.0.0/16" -j ACCEPT

iptables  -t nat -A POSTROUTING -s "${IPV4POOL}.0.0/16" -o "${ETH0}" -j MASQUERADE

# drop the rest
iptables  -A INPUT   -j DROP
iptables  -A FORWARD -j DROP

# save
netfilter-persistent save

# NETWORKING

grep -Fq 'jawj/wireguard-setup' /etc/sysctl.conf || echo "
# https://github.com/jawj/wireguard-setup
# for Wireguard
net.ipv4.ip_forward = 1

# for security
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0

# no IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
net.ipv6.conf.${ETH0}.disable_ipv6 = 1
" >> /etc/sysctl.conf

sysctl -p

# WIREGUARD

wg genkey > /etc/wireguard/private.key
chmod 600 /etc/wireguard/private.key
wg pubkey < /etc/wireguard/private.key > /etc/wireguard/public.key

echo "
[Interface]
PrivateKey = $(cat /etc/wireguard/private.key)
Address = ${IPV4POOL}.0.1/16
ListenPort = ${WGPORT}
" > /etc/wireguard/wg0.conf

systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0
wg show
