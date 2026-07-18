# NetworkManager resolver policy

`20-dns.conf` makes NetworkManager write `/etc/resolv.conf` directly with the
DNS servers and search domain supplied by the active connection/DHCP lease.
Install it as `/etc/NetworkManager/conf.d/20-dns.conf`.

The tested machine does not run systemd-networkd, systemd-resolved or Avahi.
Its DHCP server supplies the `lan` search domain.  This file does not hard-code
that domain; use a NetworkManager connection `ipv4.dns-search` only if DHCP
does not provide it.

If one important LAN host must survive an intermittently unavailable router
DNS service, add a stable, locally appropriate line to `/etc/hosts`, for
example:

```text
192.0.2.10 buildhost.example.lan buildhost
```

Do not copy the tested machine's private address or hostname blindly.
