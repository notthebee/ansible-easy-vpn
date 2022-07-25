#!/bin/bash -uxe
# A bash script that prepares the OS
# before running the Ansible playbook

# Discard stdin. Needed when running from an one-liner which includes a newline
read -N 999999 -t 0.001

# Quit on error
set -e

# Detect OS
if grep -qs "ubuntu" /etc/os-release; then
	os_version=$(grep 'VERSION_ID' /etc/os-release | cut -d '"' -f 2 | tr -d '.')
else
	echo "This installer seems to be running on an unsupported distribution.
Supported distros are Ubuntu 20.04 and 22.04"
	exit
fi

# Check if the Ubuntu version is too old
if [[ "$os" == "ubuntu" && "$os_version" -lt 2004 ]]; then
	echo "Ubuntu 20.04 or higher is required to use this installer.
This version of Ubuntu is too old and unsupported."
	exit
fi


check_root() {
# Check if the user is root or not
if [[ $EUID -ne 0 ]]; then
  if [[ ! -z "$1" ]]; then
    SUDO='sudo -E -H'
  else
    SUDO='sudo -E'
  fi
else
  SUDO=''
fi
}

check_root
# Disable interactive functionality
export DEBIAN_FRONTEND=noninteractive

# Update apt database, update all packages and install Ansible + dependencies
$SUDO apt update -y;
yes | $SUDO apt-get -o Dpkg::Options::="--force-confold" -fuy dist-upgrade;
yes | $SUDO apt-get -o Dpkg::Options::="--force-confold" -fuy install software-properties-common dnsutils curl git python3 python3-setuptools python3-apt python3-pip python3-passlib python3-wheel python3-bcrypt aptitude -y;
yes | $SUDO apt-get -o Dpkg::Options::="--force-confold" -fuy autoremove;
[ $(uname -m) == "aarch64" ] && $SUDO yes | apt install gcc dnsutils python3-dev libffi-dev libssl-dev make -y;

check_root "-H"

$SUDO pip3 install ansible &&
export DEBIAN_FRONTEND=

check_root
# Clone the Ansible playbook
[ -d "$HOME/ansible-easy-vpn" ] || git clone https://github.com/notthebee/ansible-easy-vpn $HOME/ansible-easy-vpn

cd $HOME/ansible-easy-vpn && ansible-galaxy install -r requirements.yml

clear
echo "Welcome to ansible-easy-vpn!"
echo
echo "This script is interactive"
echo "If you prefer to fill in the inventory.yml file manually,"
echo "press [Ctrl+C] to quit this script"
echo
echo "Enter your desired UNIX username"
read -p "Username: " username
until [[ "$username" =~ ^[a-z0-9]*$ ]]; do
  echo "Invalid username"
  echo "Make sure the username only contains lowercase letters and numbers"
  read -p "Username: " username
done

sed -i "s/username: .*/username: ${username}/g" $HOME/ansible-easy-vpn/inventory.yml

echo
echo "Enter your user password"
echo "This password will be used for Authelia login, administrative access and SSH login"
read -s -p "Password: " user_password
until [[ "${#user_password}" -lt 60 ]]; do
  echo
  echo "The password is too long"
  echo "OpenSSH does not support passwords longer than 72 characters"
  read -s -p "Password: " user_password
done
echo
read -s -p "Repeat password: " user_password2
echo
until [[ "$user_password" == "$user_password2" ]]; do
  echo
  echo "The passwords don't match"
  read -s -p "Password: " user_password
  echo
  read -s -p "Repeat password: " user_password2
done


echo
echo
echo "Enter your domain name"
echo "The domain name should already resolve to the IP address of your server"
echo "Make sure that 'wg' and 'auth' subdomains also point to that IP (not necessary with DuckDNS)"
echo
read -p "Domain name: " root_host
until [[ "$root_host" =~ ^[a-z0-9\.\-]*$ ]]; do
  echo "Invalid domain name"
  read -p "Domain name: " root_host
done

public_ip=$(curl -s ipinfo.io/ip)
domain_ip=$(dig +short ${root_host})

until [[ $domain_ip =~ $public_ip ]]; do
  echo
  echo "The domain $root_host does not resolve to the public IP of this server ($public_ip)"
  echo
  read -p "Domain name: " root_host
  public_ip=$(curl -s ipinfo.io/ip)
  domain_ip=$(dig +short ${root_host})
  echo
done


sed -i "s/root_host: .*/root_host: ${root_host}/g" $HOME/ansible-easy-vpn/inventory.yml

echo
echo "Would you like to use an existing SSH key?"
echo "Press 'n' if you want to generate a new SSH key pair"
echo
read -p "Use existing SSH key? [y/N]: " new_ssh_key_pair
until [[ "$new_ssh_key_pair" =~ ^[yYnN]*$ ]]; do
        echo "$new_ssh_key_pair: invalid selection."
        read -p "[y/N]: " new_ssh_key_pair
done
sed -i "s/enable_ssh_keygen: .*/enable_ssh_keygen: true/g" $HOME/ansible-easy-vpn/inventory.yml

if [[ "$new_ssh_key_pair" =~ ^[yY]$ ]]; then
  echo
  read -p "Please enter your SSH public key: " ssh_key_pair

  # sed will crash if the SSH key is multi-line
  sed -i "s/# ssh_public_key: .*/ssh_public_key: ${ssh_key_pair}/g" $HOME/ansible-easy-vpn/inventory.yml || echo "Fixing the sed error..." && echo "    ssh_public_key: ${ssh_key_pair}" >> $HOME/ansible-easy-vpn/inventory.yml
fi

echo
echo "Would you like to set up the e-mail functionality?"
echo "It will be used to confirm the 2FA setup and restore the password in case you forget it"
echo
echo "This is optional"
echo
read -p "Set up e-mail? [y/N]: " email_setup
until [[ "$email_setup" =~ ^[yYnN]*$ ]]; do
				echo "$email_setup: invalid selection."
				read -p "[y/N]: " email_setup
done

if [[ "$email_setup" =~ ^[yY]$ ]]; then
  echo
  read -p "SMTP server: " email_smtp_host
  until [[ "$email_smtp_host" =~ ^[a-z0-9\.]*$ ]]; do
    echo "Invalid SMTP server"
    read -p "SMTP server: " email_smtp_host
  done
  echo
  read -p "SMTP port [465]: " email_smtp_port
  if [ -z ${email_smtp_port} ]; then
    email_smtp_port="465"
  fi
  echo
  read -p "SMTP login: " email_login
  echo
  read -s -p "SMTP password: " email_password
  until [[ ! -z "$email_password" ]]; do
    echo "The password is empty"
    read -s -p "SMTP password: " email_password
  done
  echo
  echo
  read -p "'From' e-mail [${email_login}]: " email
  if [ -z ${email} ]; then
    email=$email_login
  fi

  sed -i "s/email_smtp_host: .*/email_smtp_host: ${email_smtp_host}/g" $HOME/ansible-easy-vpn/inventory.yml
  sed -i "s/email_smtp_port: .*/email_smtp_port: ${email_smtp_port}/g" $HOME/ansible-easy-vpn/inventory.yml
  sed -i "s/email_login: .*/email_login: ${email_login}/g" $HOME/ansible-easy-vpn/inventory.yml
  sed -i "s/email: .*/email: ${email}/g" $HOME/ansible-easy-vpn/inventory.yml
fi


# Set secure permissions for the Vault file
touch $HOME/ansible-easy-vpn/secret.yml
chmod 600 $HOME/ansible-easy-vpn/secret.yml

if [ -z ${email_password+x} ]; then
  echo
else 
  echo "email_password: ${email_password}" >> $HOME/ansible-easy-vpn/secret.yml
fi

echo "user_password: ${user_password}" >> $HOME/ansible-easy-vpn/secret.yml

jwt_secret=$(openssl rand -hex 23)
session_secret=$(openssl rand -hex 23)
storage_encryption_key=$(openssl rand -hex 23)

echo "jwt_secret: ${jwt_secret}" >> $HOME/ansible-easy-vpn/secret.yml
echo "session_secret: ${session_secret}" >> $HOME/ansible-easy-vpn/secret.yml
echo "storage_encryption_key: ${storage_encryption_key}" >> $HOME/ansible-easy-vpn/secret.yml

echo
echo "Encrypting the variables"
ansible-vault encrypt $HOME/ansible-easy-vpn/secret.yml

echo
echo "Success!"
read -p "Would you like to run the playbook now? [y/N]: " launch_playbook
until [[ "$launch_playbook" =~ ^[yYnN]*$ ]]; do
				echo "$launch_playbook: invalid selection."
				read -p "[y/N]: " launch_playbook
done

if [[ "$launch_playbook" =~ ^[yY]$ ]]; then
  if [[ $EUID -ne 0 ]]; then
    echo
    echo "Please enter your current sudo password now"
    cd $HOME/ansible-easy-vpn && ansible-playbook -K run.yml
  else
    cd $HOME/ansible-easy-vpn && ansible-playbook run.yml
  fi
else
  echo "You can run the playbook by executing the following command"
  echo "cd ${HOME}/ansible-easy-vpn && ansible-playbook run.yml"
  exit
fi
