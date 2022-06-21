#!/bin/bash -uxe
# A bash script that prepares the OS
# before running the Ansible playbook

export DEBIAN_FRONTEND=noninteractive
apt update -y;
yes | apt-get -o Dpkg::Options::="--force-confold" -fuyqq dist-upgrade;
yes | apt-get -o Dpkg::Options::="--force-confold" -fuyqq install software-properties-common curl git facter python3 python3-setuptools python3-apt python3-pip python3-passlib python3-wheel python3-bcrypt aptitude -y;
[ $(uname -m) == "aarch64" ] && yes | apt install gcc python3-dev libffi-dev libssl-dev make -yqq;

export DEBIAN_FRONTEND=
pip3 install ansible -U &&
[ -d "/root/ansible-easy-vpn" ] || git clone https://github.com/notthebee/ansible-easy-vpn
