# ansible-easy-vpn
![CI](https://github.com/notthebee/ansible-easy-vpn/actions/workflows/ci.yml/badge.svg)

A simple interactive script/Ansible playbook that sets up a Wireguard VPN server on your VPS of choice


## Usage

```
wget https://notthebe.ee/vpn -O bootstrap.sh && bash bootstrap.sh
```

## Features
* Automated and unattended upgrades
* SSH hardening
* SSH public key pair generation (optional, you can also use your own keys)
* E-mail notifications (using an external SMTP server e.g. GMail)
* UFW and Fail2Ban
* Wireguard WebUI (via wg-easy)
* Two-factor authentication for the WebUI (Authelia)
* Hardened web server (Bunkerweb)
* **[new]** Support for Adguard, Unbound and DNS-over-HTTPS (for ad blocking functionality and secure DNS resolution)
  * The Adguard WebUI will be accessible at **adguard.yourdomainname.com** after the installation is finished


## Requirements
* A KVM-based VPS (or an AWS EC2 instance) with a dedicated IPv4 address
* Ubuntu Server 20.04/22.04 or Debian 11

## FAQ
### Q: I've run the playbook succesfully, but now I want to change the domain name/username/password. How can I do that?

Edit the variable files, install dependencies for the new user and re-run the playbook:

```
cd $HOME/ansible-easy-vpn
ansible-galaxy install -r requirements.yml
nano custom.yml
ansible-vault edit secret.yml
ansible-playbook run.yml
```


### Q: I get a "Secure connection failed" error when trying to access the Wireguard WebUI in the browser

This usually means that Let's Encrypt has failed to generate the certificates for your domain name.

There are a few reasons why that might happen:

1. Firewall misconfiguration (are the ports 80 and 443 open?)
2. The server is behind NAT (make sure that the ports 80 and 443 are port-forwarded to the server's internal IP on the router)
3. Let's Encrypt has time-limited your domain name (try a different domain name)

Check the Bunkerweb logs for more details:
```
docker logs bunkerweb
```

### Q: I get "500 Internal Server Error" when trying to access the Wireguard WebUI in the browser

Most likely, you chose to configure the e-mail functionality, but entered wrong SMTP credentials. Check out Authelia logs for details:
```
docker logs authelia
```

### Q: My SMTP credentials are correct, but I still get the HTTP 500 error the Authelia logs show an "i/o timeout" error
```
error dialing the SMTP server: dial tcp: lookup smtp.example.com: i/o timeout"
```
This error message indicates that your VPS provider is blocking the SMTP ports (465/25).

Ask the provider to unblock the ports or disable the e-mail functionality by removing the `email_password` line from secret.yml and re-run the playbook:
```
cd $HOME/ansible-easy-vpn
ansible-galaxy install -r requirements.yml
ansible-vault edit secret.yml
ansible-playbook run.yml
```


### Q: I'd like to completely automate the process of setting up the VPN on my machines. How can I do that?
1. Fork this repository
2. Fill out the `custom.yml` and `secret.yml` files, either by running the `bootstrap.sh` script, or editing the files manually
3. Remove `secret.yml` from .gitignore
4. Commit and push the changes

Consider making your repository private. Even though the Vault file is encrypted, it might be unsafe to make it publicly accessible.

### Q: I can't copy the SSH key to my Windows machine

On Windows, you might need to create the `C:\Users\<username>\.ssh` folder manually before running the commands at the end of the playbook:
```
mkdir C:\Users\<username>\.ssh
scp -P 22 root@<server-ip-address>:/tmp/id_ssh_ed25519 C:\Users\<username>\.ssh
ssh -p 22 <username>@<server-ip-address> -i C:\Users\<username>\.ssh\id_ssh_ed25519
```
