#!/bin/bash -e

# github.com/jawj/wireguard-setup
# Copyright (c) 2025 George MacKerron
# Released under the MIT licence: http://opensource.org/licenses/mit-license

IPV4POOL="$(cat /etc/wireguard/ipv4pool)"

read -r -p "Name/desscription of client: " CLIENTNAME
CLIENTNAME="${CLIENTNAME:-unknown}"

echo '
Public DNS servers include:

176.103.130.130,176.103.130.131  AdGuard               https://adguard.com/en/adguard-dns/overview.html
176.103.130.132,176.103.130.134  AdGuard Family

1.1.1.1,1.0.0.1                  Cloudflare            https://one.one.one.one
1.1.1.2,1.0.0.2                  Cloudflare, blocks malware
1.1.1.3,1.0.0.3                  Cloudflare, blocks malware and adult content

84.200.69.80,84.200.70.40        DNS.WATCH             https://dns.watch

8.8.8.8,8.8.4.4                  Google                https://developers.google.com/speed/public-dns/

208.67.222.222,208.67.220.220    OpenDNS               https://www.opendns.com
208.67.222.123,208.67.220.123    OpenDNS FamilyShield

9.9.9.9,149.112.112.112          Quad9                 https://quad9.net

77.88.8.8,77.88.8.1              Yandex                https://dns.yandex.com
77.88.8.88,77.88.8.2             Yandex Safe
77.88.8.7,77.88.8.3              Yandex Family
'

read -r -p "DNS servers for client (default: 1.1.1.1,1.0.0.1): " DNS
DNS="${DNS:-1.1.1.1,1.0.0.1}"

NEXTCLIENT="$((2 + $(grep -c "\[Peer\]" /etc/wireguard/wg0.conf || true)))"

CLIENT_PRIV="$(wg genkey)"
CLIENT_PUB="$(echo -n "${CLIENT_PRIV}" | wg pubkey)"
CLIENT_IPV4="${IPV4POOL}.0.${NEXTCLIENT}"

IPV4="$(dig -4 +short myip.opendns.com @resolver1.opendns.com)"
WGPORT="$(grep ListenPort /etc/wireguard/wg0.conf | grep -oE "[0-9]+")"

echo "[Peer] # ${CLIENTNAME}
PublicKey = ${CLIENT_PUB}
AllowedIPs = ${CLIENT_IPV4}/32
" >> /etc/wireguard/wg0.conf

systemctl reload wg-quick@wg0.service

CLIENT_CONF="
[Interface]
PrivateKey = ${CLIENT_PRIV}
Address = ${CLIENT_IPV4}/16
DNS = ${DNS}

[Peer]
PublicKey = $(cat /etc/wireguard/public.key)
AllowedIPs = ::/0,1.0.0.0/8,2.0.0.0/8,3.0.0.0/8,4.0.0.0/6,8.0.0.0/7,11.0.0.0/8,12.0.0.0/6,16.0.0.0/4,32.0.0.0/3,64.0.0.0/2,128.0.0.0/3,160.0.0.0/5,168.0.0.0/6,172.0.0.0/12,172.32.0.0/11,172.64.0.0/10,172.128.0.0/9,173.0.0.0/8,174.0.0.0/7,176.0.0.0/4,192.0.0.0/9,192.128.0.0/11,192.160.0.0/13,192.169.0.0/16,192.170.0.0/15,192.172.0.0/14,192.176.0.0/12,192.192.0.0/10,193.0.0.0/8,194.0.0.0/7,196.0.0.0/6,200.0.0.0/5,208.0.0.0/4,1.1.1.1/32
Endpoint = ${IPV4}:${WGPORT}
PersistentKeepalive = 25
"

echo "=== Client config for ${CLIENTNAME} ==="
echo "${CLIENT_CONF}"
echo -n "${CLIENT_CONF}" | qrencode -t ANSI256UTF8
