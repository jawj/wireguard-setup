#!/bin/bash -e

# github.com/jawj/wireguard-setup
# Copyright (c) 2025 George MacKerron
# Released under the MIT licence: http://opensource.org/licenses/mit-license


# INSTALL PACKAGES

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y wireguard unbound apt-utils dnsutils language-pack-en iptables-persistent unattended-upgrades qrencode


# GATHER INFO

ETH0=$(ip route get 1.1.1.1 | grep -oP ' dev \K\S+')
echo "Network interface: ${ETH0}"

IPV4=$(dig -4 +short myip.opendns.com @resolver1.opendns.com)
echo "External IPv4: ${IPV4}"

IPV6=$(dig AAAA +short myip.opendns.com @resolver1.opendns.com)
echo "External IPv6: ${IPV6}"

IPV4POOL="10.102"
echo -n "${IPV4POOL}" > /etc/wireguard/ipv4pool
echo "IPv4 pool: ${IPV4POOL}.0.0/16"

IPV6ULA="fd$(openssl rand -hex 1):$(openssl rand -hex 2):$(openssl rand -hex 2):$(openssl rand -hex 2)"
[[ -f /etc/wireguard/ipv6ula ]] && IPV6ULA="$(cat /etc/wireguard/ipv6ula)"
[[ -f /etc/wireguard/ipv6ula ]] || echo -n "${IPV6ULA}" > /etc/wireguard/ipv6ula
echo "IPv6 ULAs: ${IPV6ULA}::0/64"

read -r -p "Timezone (default: Europe/London): " TZONE
TZONE=${TZONE:-'Europe/London'}

read -r -p "Desired SSH log-in port (default: 22): " SSHPORT
SSHPORT=${SSHPORT:-22}

read -r -p "Desired Wireguard port (default: 51820): " WGPORT
WGPORT=${WGPORT:-51820}


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
-i /etc/ssh/sshd_config

service ssh restart


# FIREWALL

iptables  -P INPUT   ACCEPT
ip6tables -P INPUT   ACCEPT
iptables  -P FORWARD ACCEPT
ip6tables -P FORWARD ACCEPT
iptables  -P OUTPUT  ACCEPT
ip6tables -P OUTPUT  ACCEPT

iptables  -F
ip6tables -F
iptables  -t nat -F
ip6tables -t nat -F

# accept anything already accepted
iptables  -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
ip6tables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# accept anything on the loopback interface
iptables  -A INPUT -i lo -j ACCEPT
ip6tables -A INPUT -i lo -j ACCEPT

# drop invalid packets
iptables  -A INPUT -m conntrack --ctstate INVALID -j DROP
ip6tables -A INPUT -m conntrack --ctstate INVALID -j DROP

# rate-limit repeated new requests from same IP to any ports
iptables  -I INPUT -i "${ETH0}" -m state --state NEW -m recent --set
ip6tables -I INPUT -i "${ETH0}" -m state --state NEW -m recent --set
iptables  -I INPUT -i "${ETH0}" -m state --state NEW -m recent --update --seconds 300 --hitcount 60 -j DROP
ip6tables -I INPUT -i "${ETH0}" -m state --state NEW -m recent --update --seconds 300 --hitcount 60 -j DROP

# accept SSH + WireGuard
iptables  -A INPUT -p tcp --dport "${SSHPORT}" -j ACCEPT
ip6tables -A INPUT -p tcp --dport "${SSHPORT}" -j ACCEPT
iptables  -A INPUT -p udp --dport "${WGPORT}" -i "${ETH0}" -j ACCEPT
ip6tables -A INPUT -p udp --dport "${WGPORT}" -i "${ETH0}" -j ACCEPT

# accept DNS from WireGuard clients
iptables  -A INPUT -p udp --dport 53 -i wg0 -j ACCEPT
ip6tables -A INPUT -p udp --dport 53 -i wg0 -j ACCEPT
iptables  -A INPUT -p tcp --dport 53 -i wg0 -j ACCEPT
ip6tables -A INPUT -p tcp --dport 53 -i wg0 -j ACCEPT

# ICMP IPv4
iptables -A INPUT -p icmp -m icmp --icmp-type 8 -m limit --limit 1/second -j ACCEPT  # rate-limited ping
iptables -A INPUT -p icmp -m icmp --icmp-type 3 -j ACCEPT  # destination unreachable
iptables -A INPUT -p icmp -m icmp --icmp-type 11 -j ACCEPT  # time exceeded

# ICMP IPv6
ip6tables -A INPUT -p ipv6-icmp -m icmp6 --icmpv6-type 128 -m limit --limit 1/second -j ACCEPT  # rate-limited ping
ip6tables -A INPUT -p ipv6-icmp -m icmp6 --icmpv6-type 135 -j ACCEPT  # critical! neighbor solicitation
ip6tables -A INPUT -p ipv6-icmp -m icmp6 --icmpv6-type 136 -j ACCEPT  # critical! neighbor advertisement
ip6tables -A INPUT -p ipv6-icmp -m icmp6 --icmpv6-type 1 -j ACCEPT  # destination unreachable
ip6tables -A INPUT -p ipv6-icmp -m icmp6 --icmpv6-type 2 -j ACCEPT  # packet too big
ip6tables -A INPUT -p ipv6-icmp -m icmp6 --icmpv6-type 3 -j ACCEPT  # time exceeded
ip6tables -A INPUT -p ipv6-icmp -m icmp6 --icmpv6-type 4 -j ACCEPT  # parameter problem

# forward Wireguard traffic
iptables  -A FORWARD -i "${ETH0}" -o wg0 -d "${IPV4POOL}.0.0/16" -j ACCEPT
ip6tables -A FORWARD -i "${ETH0}" -o wg0 -d "${IPV6ULA}::/64"    -j ACCEPT

iptables  -A FORWARD -i wg0 -o "${ETH0}" -s "${IPV4POOL}.0.0/16" -j ACCEPT
ip6tables -A FORWARD -i wg0 -o "${ETH0}" -s "${IPV6ULA}::/64"    -j ACCEPT

iptables  -t nat -A POSTROUTING -s "${IPV4POOL}.0.0/16" -o "${ETH0}" -j MASQUERADE
ip6tables -t nat -A POSTROUTING -s "${IPV6ULA}::/64" -o "${ETH0}" -j MASQUERADE

# drop the rest
iptables  -A INPUT   -j DROP
ip6tables -A INPUT   -j DROP
iptables  -A FORWARD -j DROP
ip6tables -A FORWARD -j DROP

# save
netfilter-persistent save


# IP FORWARDING

echo "
# WireGuard, IPv4
net.ipv4.ip_forward = 1

# WireGuard, IPv6 (https://dotat.at/@/2024-04-30-wireguard.html)
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.${ETH0}.accept_ra = 2
" > /etc/sysctl.conf

sysctl -p


# DNS FORWARDING

echo "
server:
    interface: ${IPV4POOL}.0.1
    interface: ${IPV6ULA}::1

    access-control: ${IPV4POOL}.0.0/16 allow
    access-control: ${IPV6ULA}::/64 allow
    access-control: 0.0.0.0/0 refuse
    access-control: ::/0 refuse

    do-ip4: yes
    do-ip6: yes
    do-udp: yes
    do-tcp: yes

    # privacy and security
    hide-identity: yes
    hide-version: yes
    harden-glue: yes
    harden-dnssec-stripped: yes
    use-caps-for-id: no

    # performance
    cache-max-ttl: 86400
    prefetch: yes

    # DNS-over-TLS forwarding to Cloudflare
    forward-zone:
        name: \".\"
        forward-tls-upstream: yes
        forward-addr: 1.1.1.1@853#cloudflare-dns.com
        forward-addr: 1.0.0.1@853#cloudflare-dns.com
        forward-addr: 2606:4700:4700::1111@853#cloudflare-dns.com
        forward-addr: 2606:4700:4700::1001@853#cloudflare-dns.com

" > /etc/unbound/unbound.conf.d/wireguard-dot.conf

systemctl enable unbound
systemctl restart unbound


# WIREGUARD

[[ -f /etc/wireguard/private.key ]] || wg genkey > /etc/wireguard/private.key
chmod 600 /etc/wireguard/private.key
wg pubkey < /etc/wireguard/private.key > /etc/wireguard/public.key

[[ -f /etc/wireguard/wg0.conf ]] || echo "
[Interface]
PrivateKey = $(cat /etc/wireguard/private.key)
Address = ${IPV4POOL}.0.1/16,${IPV6ULA}::1/64
ListenPort = ${WGPORT}
" > /etc/wireguard/wg0.conf

systemctl enable wg-quick@wg0
systemctl restart wg-quick@wg0
wg show
