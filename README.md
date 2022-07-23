# ansible-easy-vpn

A simple interactive script/Ansible playbook that sets up an Ubuntu-based Wireguard VPN server

### Features
* Automated and unattended upgrades
* SSH hardening
* SSH public key pair generation (optional, you can also use your own keys)
* E-mail notifications (using an external SMTP server e.g. GMail)
* UFW and Fail2Ban
* Wireguard WebUI (via wg-easy)
* Two-factor authentication for the WebUI (Authelia)
* Hardened web server (Bunkerweb)

### Requirements
* A KVM-based VPS with a dedicated IPv4 address
* Ubuntu Server 20.04 or 22.04

### Usage

```
wget https://raw.githubusercontent.com/notthebee/ansible-easy-vpn/main/bootstrap.sh -O bootstrap.sh && bash bootstrap.sh
```


**Q: I've run the playbook succesfully, but now I want to change the domain name/username/password. How can I do that?**

Edit the variable files and re-run the playbook:

```
cd $HOME/ansible-easy-vpn
nano inventory.yml
# or
ansible-vault edit secret.yml

ansible-playbook run.yml
```


**Q: I can't access the Wireguard WebUI after running the playbook**

Most likely, the culprit is an incorrect domain name. Check the Bunkerweb logs:
```
docker logs bunkerweb
```

Another reason might be wrong SMTP credentials. Check out Authelia logs:
```
docker logs authelia
```
