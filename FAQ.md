# Frequently Asked Questions

* [I can connect to the VPN, but can't access the Internet](#q-i-can-connect-to-the-vpn-but-cant-access-the-internet)
* [I've run the playbook succesfully, but now I want to change the domain name/username/password. How can I do that?](#q-ive-run-the-playbook-succesfully-but-now-i-want-to-change-the-domain-nameusernamepassword-how-can-i-do-that)
* [I get a "Secure connection failed" error when trying to access the Wireguard WebUI in the browser](#q-i-get-a-secure-connection-failed-error-when-trying-to-access-the-wireguard-webui-in-the-browser)
* [I get "500 Internal Server Error" when trying to access the Wireguard WebUI in the browser](#q-i-get-500-internal-server-error-when-trying-to-access-the-wireguard-webui-in-the-browser)
* [My SMTP credentials are correct, but I still get the HTTP 500 error, and the Authelia logs show an "i/o timeout" error](#q-my-smtp-credentials-are-correct-but-i-still-get-the-http-500-error-and-the-authelia-logs-show-an-io-timeout-error)
* [I'd like to completely automate the process of setting up the VPN on my machines. How can I do that?](#q-id-like-to-completely-automate-the-process-of-setting-up-the-vpn-on-my-machines-how-can-i-do-that)
* [When I try to copy the SSH key to my Windows machine, I get an error](#q-when-i-try-to-copy-the-ssh-key-to-my-windows-machine-i-get-an-error)
* [I've lost my second factor device. How do I reset the 2FA?](#q-ive-lost-my-second-factor-device-how-do-i-reset-the-2fa)
* [I can't access the Internet after connecting to the Wireguard server](#q-i-cant-access-the-internet-after-connecting-to-the-wireguard-server)

### Q: I can connect to the VPN, but can't access the Internet

Unfortunately, most Wireguard clients are a bit misleading in that regard. If you can connect to the VPN, but see very little data in the 'Received' column and can't access the Internet, this most likely means that **you actually can't connect to the VPN server**.

The most common reason for that is a firewall blocking the Wireguard port – either on the VPS side, or on the client side. Your VPS provider may apply some default firewall rules to your server, which you can edit in the web control panel of your VPS provider.

Alternatively, your ISP may be blocking the default Wireguard port (51820/udp). This can be fixed by changing the port to something else (for examlpe, 12345), and re-running the playbook:

```
cd $HOME/ansible-easy-vpn
echo 'wireguard_port: "12345"` >> custom.yml
bash bootstrap.sh
```


### Q: I've run the playbook succesfully, but now I want to change the domain name/username/password. How can I do that?

A: Edit the variable files, and then re-run the script

```
cd $HOME/ansible-easy-vpn
nano custom.yml 
ansible-vault edit secret.yml
bash bootstrap.sh
```

### Q: I get a "Secure connection failed" error when trying to access the Wireguard WebUI in the browser

A: This usually means that Let's Encrypt has failed to generate the certificates for your domain name.

There are a few reasons why that might happen:

1. Firewall misconfiguration (are the ports 80 and 443 open?)
2. The server is behind NAT (make sure that the ports 80 and 443 are port-forwarded to the server's internal IP on the router)
3. Let's Encrypt has time-limited your domain name (try a different domain name)

Check the Bunkerweb logs for more details:
```
docker logs bunkerweb
```

You can use the commands from the previous answer to change your domain name.

### Q: I get "500 Internal Server Error" when trying to access the Wireguard WebUI in the browser

A: Most likely, you chose to configure the e-mail functionality, but entered wrong SMTP credentials. Check out Authelia logs for details:
```
docker logs authelia
```
You can either disable e-mail functionality entirely, by removing the `email_password` variable from `secret.yml`, or enter the correct SMTP credentials. In both cases, you'll need to re-run the playbook after the changes have been made:
```
cd $HOME/ansible-easy-vpn
ansible-vault edit secret.yml
bash bootstrap.sh
```

### Q: My SMTP credentials are correct, but I still get the HTTP 500 error, and the Authelia logs show an "i/o timeout" error

A: This error message indicates that your VPS provider is blocking the SMTP ports (465/25).

```
error dialing the SMTP server: dial tcp: lookup smtp.example.com: i/o timeout"
```

Ask the provider to unblock the ports or disable the e-mail functionality by removing the `email_password` line from secret.yml and re-run the playbook:
```
cd $HOME/ansible-easy-vpn
ansible-vault edit secret.yml
bash bootstrap.sh
```

### Q: I'd like to completely automate the process of setting up the VPN on my machines. How can I do that?

1. Fork this repository
2. Fill out the `custom.yml` and `secret.yml` files, either by running the `bootstrap.sh` script, or editing the files manually
3. Remove `secret.yml` from .gitignore
4. Commit and push the changes

Consider making your repository private. Even though the Vault file is encrypted, it might be unsafe to make it publicly accessible.

### Q: When I try to copy the SSH key to my Windows machine, I get an error

A: On Windows, you might need to omit the `~/` before `.ssh`:
```
cd ~
scp -P 22 root@65.109.141.154:/tmp/id_ssh_ed25519 .ssh/id_vpn_username
ssh -p 22 username@65.109.141.154 -i .ssh/id_vpn_username
```


### Q: I've lost my second factor device. How do I reset the 2FA?

A: Log in to the server via SSH and execute the following commands:
```
docker stop authelia && docker rm authelia
sudo rm -rf /opt/docker/authelia
cd $HOME/ansible-easy-vpn
bash bootstrap.sh
```

### Q: I can't access the Internet after connecting to the Wireguard server

A: Most likely, your VPS features a firewall that is enabled by default and blocks access on non-standard ports. 

You will need to go to the control panel/WebUI of your VPS and add a new firewall rule to open the Wireguard port (51820/udp by default).
