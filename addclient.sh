#!/bin/bash -e

# github.com/jawj/wireguard-setup
# Copyright (c) 2025 George MacKerron
# Released under the MIT licence: http://opensource.org/licenses/mit-license

echo "This script adds a WireGuard peer."

function exit_badly {
  echo "$1"
  exit 1
}

[[ "$(id -u)" -eq 0 ]] || exit_badly "Please run as root (e.g. sudo ./path/to/this/script)"
[[ -f /etc/wireguard/ipv4pool ]] || exit_badly "WireGuard does not appear to have been set up via setup.sh"

IPV4POOL="$(cat /etc/wireguard/ipv4pool)"
IPV6ULA="$(cat /etc/wireguard/ipv6ula)"

read -r -p "Name/description of client: " CLIENTNAME
CLIENTNAME="${CLIENTNAME:-unknown}"

NEXTCLIENT="$((2 + $(grep -c "\[Peer\]" /etc/wireguard/wg0.conf || true)))"
NEXTHEX="$(printf "%X" "${NEXTCLIENT}")"

CLIENT_PRIV="$(wg genkey)"
CLIENT_PUB="$(echo -n "${CLIENT_PRIV}" | wg pubkey)"
CLIENT_IPV4="${IPV4POOL}.0.${NEXTCLIENT}"
CLIENT_IPV6="${IPV6ULA}::${NEXTHEX}"

IPV4="$(dig -4 +short myip.opendns.com @resolver1.opendns.com)"
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
DNS = ${IPV4POOL}.0.1,${IPV6ULA}::1

[Peer]
PublicKey = $(cat /etc/wireguard/public.key)
AllowedIPs = ::/0,1.0.0.0/8,2.0.0.0/8,3.0.0.0/8,4.0.0.0/6,8.0.0.0/7,11.0.0.0/8,12.0.0.0/6,16.0.0.0/4,32.0.0.0/3,64.0.0.0/2,128.0.0.0/3,160.0.0.0/5,168.0.0.0/6,172.0.0.0/12,172.32.0.0/11,172.64.0.0/10,172.128.0.0/9,173.0.0.0/8,174.0.0.0/7,176.0.0.0/4,192.0.0.0/9,192.128.0.0/11,192.160.0.0/13,192.169.0.0/16,192.170.0.0/15,192.172.0.0/14,192.176.0.0/12,192.192.0.0/10,193.0.0.0/8,194.0.0.0/7,196.0.0.0/6,200.0.0.0/5,208.0.0.0/4,${IPV4POOL}.0.0/16
Endpoint = ${IPV4}:${WGPORT}
PersistentKeepalive = 25
"

echo
echo "=== Client config for ${CLIENTNAME} ==="
echo
echo -n "${CLIENT_CONF}" | qrencode -t ANSI256UTF8
echo
echo "${CLIENT_CONF}"
