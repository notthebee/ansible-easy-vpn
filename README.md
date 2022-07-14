# Usage

Install curl and execute the bootstrapping script

```
apt install curl
curl -s -L https://raw.githubusercontent.com/notthebee/ansible-easy-vpn/main/prepare_system.sh | /bin/bash
cd ansible-easy-vpn
```

Create a secret variable file with your password

```
export EDITOR=nano
ansible-vault create secret.yml 
```

Enter your desired password twice and put the password in the file like this:

```
password: very_secret_password
```

Edit the inventory.yml to your liking:

```
nano inventory.yml
```

Afterwards, execute the playbook:
```
./run.yml
```
