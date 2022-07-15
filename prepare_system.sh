#!/bin/bash -uxe
# A bash script that prepares the OS
# before running the Ansible playbook

# root or not
if [[ $EUID -ne 0 ]]; then
  SUDO='sudo -H -E'
else
  SUDO=''
fi

export DEBIAN_FRONTEND=noninteractive
$SUDO apt update -y;
$SUDO yes | apt-get -o Dpkg::Options::="--force-confold" -fuy dist-upgrade;
$SUDO yes | apt-get -o Dpkg::Options::="--force-confold" -fuy install software-properties-common curl git python3 python3-setuptools python3-apt python3-pip python3-passlib python3-wheel python3-bcrypt aptitude -y;
$SUDO yes | apt-get -o Dpkg::Options::="--force-confold" -fuy autoremove;
[ $(uname -m) == "aarch64" ] && $SUDO yes | apt install gcc python3-dev libffi-dev libssl-dev make -y;

pip3 install ansible
export DEBIAN_FRONTEND=
[ -d "$HOME/ansible-easy-vpn" ] || git clone https://github.com/notthebee/ansible-easy-vpn
