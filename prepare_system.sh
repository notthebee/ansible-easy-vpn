#!/bin/bash -uxe
# A bash script that prepares the OS
# before running the Ansible playbook

passwd &&
apt update -y
apt-get -o Dpkg::Options::="--force-confold" -fuy dist-upgrade
apt-get -o Dpkg::Options::="--force-confold" -fuy install software-properties-common curl git mc vim facter python3 python3-setuptools python3-apt python3-pip python3-passlib python3-wheel python3-bcrypt aptitude -y
[ $(uname -m) == "aarch64" ] && $SUDO apt install gcc python3-dev libffi-dev libssl-dev make -y
pip3 install ansible -U
