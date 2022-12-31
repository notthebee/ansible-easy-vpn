# ansible-easy-vpn
![CI](https://github.com/notthebee/ansible-easy-vpn/actions/workflows/ci.yml/badge.svg)

A simple interactive script that sets up a Wireguard VPN server with Adguard, Unbound and DNSCrypt-Proxy on your VPS of choice, and lets you manage the config files using a simple WebUI protected by two-factor-authentication.

**Have a question or an issue? Read the [FAQ](FAQ.md) first!**

## Usage

```
wget https://notthebe.ee/vpn -O bootstrap.sh && bash bootstrap.sh
```

## Features
* Wireguard WebUI (via wg-easy)
* Two-factor authentication for the WebUI (Authelia)
* Hardened web server (Bunkerweb)
* ✨ **new!** Optional DNS-over-HTTPS and hosts-based ad-blocking (Adguard, Unbound and DNSCrypt-Proxy)
* UFW and Fail2Ban
* Automated and unattended upgrades
* SSH hardening
* SSH public key pair generation (optional, you can also use your own keys)
* E-mail notifications (using an external SMTP server e.g. GMail)


## Requirements
* A KVM-based VPS (or an AWS EC2 instance) with a dedicated IPv4 address
* Ubuntu Server 20.04/22.04 or Debian 11

## Known issues with VPS providers
Normally, the script should work on any KVM-based VPS.

However, some VPS providers use non-standard versions of Ubuntu/Debian OS images, which might lead to issues with the script.

* **AlexHost** – runs `apt-get dist-upgrade` after the VPS is provisioned, which results in a dpkg lock
