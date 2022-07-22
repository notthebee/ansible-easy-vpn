# ansible-easy-vpn

A simple interactive script/Ansible playbook that sets up an Ubuntu-based Wireguard VPN server

### Features
* Automated and unattended upgrades
* SSH hardening
* SSH public key pair generation (optional, you can also use your own keys)
* E-mail notifications (using an external SMTP server e.g. GMail)
* Wireguard WebUI (via wg-easy)
* Two-factor authentication for the WebUI (Authelia)
* Hardened web server (Bunkerweb)

### Usage

```
wget https://raw.githubusercontent.com/notthebee/ansible-easy-vpn/main/bootstrap.sh -O bootstrap.sh && bash bootstrap.sh
```
