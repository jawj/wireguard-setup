# wireguard-setup

Bash scripts to take Ubuntu Server LTS 24.04 from clean install to fully-configured WireGuard server peer.

* `setup.sh` sets up the server (run once)
* `addclient.sh` creates a peer, printing the config as text and a QR code (run for each new client)

The server is configured for unattended security upgrades and firewalled with `iptables` to allow only SSH, WireGuard and some ICMP types.

## Usage

One-time only (as `root`):

```bash
wget https://raw.githubusercontent.com/jawj/wireguard-setup/refs/heads/main/IPv4-only/setup.sh
chmod u+x setup.sh
./setup.sh
```

To add a client (as `root`):

```bash
wget https://raw.githubusercontent.com/jawj/wireguard-setup/refs/heads/main/IPv4-only/addclient.sh
chmod u+x addclient.sh
./addclient.sh
```

To show status (as `root`):

```bash
wg show
```

## License

MIT
