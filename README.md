# ansible-easy-vpn

A simple interactive script that sets up a Wireguard VPN server with Adguard, Unbound and DNSCrypt-Proxy on your VPS of choice, and lets you manage the config files using a simple WebUI protected by two-factor-authentication.

**Have a question or an issue? Read the [FAQ](FAQ.md) first!**

## Usage

```
wget https://raw.githubusercontent.com/MacchiaGuardala/ansible-easy-vpn/main/bootstrap.sh -O bootstrap.sh && bash bootstrap.sh
```

## Features
* Wireguard WebUI (via wg-easy)
* Two-factor authentication for the WebUI (Authelia)
* Hardened web server (Bunkerweb)
* Encrypted DNS resolution with optional ad-blocking functionality (Adguard Home, DNSCrypt and Unbound)
* IPTables firewall with sane defaults and Fail2Ban
* Automated and unattended upgrades
* SSH hardening and public key pair generation (optional, you can also use your own keys)
* E-mail notifications (using an external SMTP server, e.g. GMail)

## Requirements
* A KVM-based VPS (or an AWS EC2 instance) with a dedicated IPv4 address
* One of the supported Linux distros:
  * Ubuntu Server 22.04
  * Ubuntu Server 20.04
  * Debian 11
  * Debian 12
  * ~~Rocky Linux 8~~ – not supported anymore
  * ~~Rocky Linux 9~~ - not supported anymore

## Known issues with VPS providers
Normally, the script should work on any KVM-based VPS.

However, some VPS providers use non-standard versions of Ubuntu/Debian OS images, which might lead to issues with the script.

Additionally, some providers require additional firewall configuration in the server control panel to unblock the Wireguard port.

* **AlexHost** – runs `apt-get dist-upgrade` after the VPS is provisioned, which results in a dpkg lock
* **IONOS** – includes a firewall with default rules, which blocks Wireguard traffic. User needs to open the Wireguard port (51820/udp) in the control panel to make the VPN work.
