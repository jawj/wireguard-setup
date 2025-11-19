#!/bin/bash -e

# github.com/jawj/wireguard-setup
# Copyright (c) 2025 George MacKerron
# Released under the MIT licence: http://opensource.org/licenses/mit-license

IPV4POOL="$(cat /etc/wireguard/ipv4pool)"
IPV6ULA="$(cat /etc/wireguard/ipv6ula)"

read -r -p "Name/description of client: " CLIENTNAME
CLIENTNAME="${CLIENTNAME:-unknown}"

echo '
Public DNS servers include:

1.1.1.1,1.0.0.1,2606:4700:4700::1111,2606:4700:4700::1001        Cloudflare
1.1.1.2,1.0.0.2,2606:4700:4700::1112,2606:4700:4700::1002        + block malware
1.1.1.3,1.0.0.3,2606:4700:4700::1113,2606:4700:4700::1003        + block malware, adult

94.140.14.140,94.140.14.141,2a10:50c0::1:ff,2a10:50c0::2:ff      AdGuard (non-filtering)
94.140.14.14,94.140.15.15,2a10:50c0::ad1:ff,2a10:50c0::ad2:ff    + block ads
94.140.14.15,94.140.15.16,2a10:50c0::bad1:ff,2a10:50c0::bad2:ff  + block ads, adult

9.9.9.10,149.112.112.10,2620:fe::10,2620:fe::fe:10               Quad9 (unsecured)
9.9.9.9,149.112.112.112,2620:fe::fe,2620:fe::9                   + block malware

8.8.8.8,8.8.4.4,2001:4860:4860::8888,2001:4860:4860::8844        Google
'

read -r -p "DNS servers for client (default: 1.1.1.1,1.0.0.1,2606:4700:4700::1111,2606:4700:4700::1001): " DNS
DNS="${DNS:-1.1.1.1,1.0.0.1,2606:4700:4700::1111,2606:4700:4700::1001}"

NEXTCLIENT="$((2 + $(grep -c "\[Peer\]" /etc/wireguard/wg0.conf || true)))"
NEXTHEX="$(printf "%X" "${NEXTCLIENT}")"

CLIENT_PRIV="$(wg genkey)"
CLIENT_PUB="$(echo -n "${CLIENT_PRIV}" | wg pubkey)"
CLIENT_IPV4="${IPV4POOL}.0.${NEXTCLIENT}"
CLIENT_IPV6="${IPV6ULA}::${NEXTHEX}"

IPV4="$(dig A +short myip.opendns.com @resolver1.opendns.com)"
IPV6="$(dig AAAA +short myip.opendns.com @resolver1.opendns.com)"
WGPORT="$(grep ListenPort /etc/wireguard/wg0.conf | grep -oE "[0-9]+")"

echo "[Peer] # ${CLIENTNAME}
PublicKey = ${CLIENT_PUB}
AllowedIPs = ${CLIENT_IPV4}/32,${CLIENT_IPV6}/128
" >> /etc/wireguard/wg0.conf

systemctl reload wg-quick@wg0.service

CLIENT_CONF="
[Interface]
PrivateKey = ${CLIENT_PRIV}
Address = ${CLIENT_IPV4}/16,${CLIENT_IPV6}/64
DNS = ${DNS}

[Peer]
PublicKey = $(cat /etc/wireguard/public.key)
AllowedIPs = ::/0,1.0.0.0/8,2.0.0.0/8,3.0.0.0/8,4.0.0.0/6,8.0.0.0/7,11.0.0.0/8,12.0.0.0/6,16.0.0.0/4,32.0.0.0/3,64.0.0.0/2,128.0.0.0/3,160.0.0.0/5,168.0.0.0/6,172.0.0.0/12,172.32.0.0/11,172.64.0.0/10,172.128.0.0/9,173.0.0.0/8,174.0.0.0/7,176.0.0.0/4,192.0.0.0/9,192.128.0.0/11,192.160.0.0/13,192.169.0.0/16,192.170.0.0/15,192.172.0.0/14,192.176.0.0/12,192.192.0.0/10,193.0.0.0/8,194.0.0.0/7,196.0.0.0/6,200.0.0.0/5,208.0.0.0/4,1.1.1.1/32
Endpoint = ${IPV4}:${WGPORT}
PersistentKeepalive = 25
"

echo
echo "=== Client config for ${CLIENTNAME} ==="
echo "${CLIENT_CONF}"
echo -n "${CLIENT_CONF}" | qrencode -t ANSI256UTF8
