# wireguard-setup

Two Bash scripts:

* `setup.sh` takes Ubuntu Server LTS 24.04 from clean install to fully-configured WireGuard server peer
* `addclient.sh` creates a new client peer, printing the config as text and a QR code

The server is configured for unattended security upgrades and firewalled with `iptables` (including [basic rate-limiting](https://debian-administration.org/article/187/Using_iptables_to_rate-limit_incoming_connections), dropping new connections if there have been 60+ connection attempts in the last 5 minutes).

## Usage

One-time only:

```bash
wget https://raw.githubusercontent.com/jawj/wireguard-setup/refs/heads/main/IPv4-only/setup.sh
chmod u+x setup.sh
./setup.sh
```

To add a client:

```bash
wget https://raw.githubusercontent.com/jawj/wireguard-setup/refs/heads/main/IPv4-only/addclient.sh
chmod u+x addclient.sh
./addclient.sh
```

To show status:

```bash
wg show
```

## Caveats

* There's no IPv6 support — and, in fact, IPv6 networking is disabled — because I haven't yet managed to make it work.
* **Don't use this unmodified on a server you use for anything else**: it does as it sees fit with various system settings.
