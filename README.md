# wireguard-setup

Bash scripts to take Ubuntu Server LTS 24.04 from clean install to fully-configured WireGuard server peer, forwarding DNS queries to Cloudflare over TLS.

* `setup.sh` sets up the server (run once)
* `addclient.sh` creates a peer, printing the config as text and a QR code (run for each new client)

The server is configured for unattended security upgrades and firewalled with `iptables` to allow only SSH, WireGuard and some ICMP types.

Clients are visible to each other, and can be found via DNS as `my-client-name.wg.internal`.

## Usage

One-time only (as `root`):

```bash
wget https://raw.githubusercontent.com/jawj/wireguard-setup/refs/heads/main/setup.sh
chmod u+x setup.sh
./setup.sh
```

To add a client (as `root`):

```bash
wget https://raw.githubusercontent.com/jawj/wireguard-setup/refs/heads/main/addclient.sh
chmod u+x addclient.sh
./addclient.sh
```

Note that IP addresses are currently allocated simply by counting how many clients are already configured. Manually deleting users from `/etc/wireguard/wg0.conf` may therefore cause new users to duplicate existing users' IP addresses.

To show status (as `root`):

```bash
wg show
```

## See also

https://github.com/jawj/IKEv2-setup

## License

MIT
