#!/bin/bash -ue
# A bash script that prepares the OS
# before running the Ansible playbook
ANSIBLE_WORK_DIR="${HOME}/ansible-easy-vpn"
GITHUB_REPO="https://github.com/notthebee/ansible-easy-vpn"

CUSTOM_FILE="${ANSIBLE_WORK_DIR}/custom.yml"
SECRET_FILE="${ANSIBLE_WORK_DIR}/secret.yml"
declare -a REQUIRED_PACKAGES
declare -a NAMESERVERS

check_aws() {
	# Check if we're running on an AWS EC2 instance
	set +e
	aws=$(curl -m 5 -s http://169.254.169.254/latest/meta-data/ami-id)

	if [[ "${aws}" =~ ^ami.*$ ]]; then
		ssh_keys_aws
	else
		ssh_keys
	fi
	set -e
}

check_certbot_dryrun() {
	echo
	echo "Running certbot in dry-run mode to test the validity of the domain..."
	${SUDO} certbot certonly \
		--non-interactive \
		--break-my-certs \
		--force-renewal \
		--agree-tos \
		--email root@localhost.com \
		--standalone \
		--staging \
		-d "${root_host}" \
		-d "wg.${root_host}" \
		-d "auth.${root_host}" || exit
	echo
	echo "OK"
}

check_domain_dns() {
	declare -a ip_array
	public_ip=$(curl -s ipinfo.io/ip)

	get_authoritive_nameservers "${root_host}"
	DNS_HOST_IDX=$(( RANDOM % ${#NAMESERVERS[@]} ))
	DNS_HOST=${NAMESERVERS["${DNS_HOST_IDX}"]}

	# Declare a hash map with subdomains and their respective IPs
	declare -A DOMAINS=(
		["root"]=""
		["wg"]=""
		["auth"]=""
	)

	# Iterate through the subdomain hashmap until all of them resolve to the IP of the server
	FAILED_CHECK=0
	for domain in "${!DOMAINS[@]}"; do
		while :
		do
			if [[ $domain == "root" ]]; then
				work_domain="${root_host}"
			else
				work_domain="${domain}.${root_host}"
			fi
			# Get IPv4 address(es) from DNS query
			# - this may return more than one IPv4 address
			# - it will also remove CNAME data (if any)
			DOMAINS[${domain}]=$(
				dig +short @"${DNS_HOST}" \
					"${work_domain}" |
					grep '[1-9]*\.[0-9]*\.[0-9]*\.[0-9]*'|tr '\n' ' '
			)
			# The public ipv4 address must be found in the set returned
			# - NB: matching must be a full exact match
			ip_array=( ${DOMAINS[${domain}]} )
			declare -p ip_array|grep -q  "\"${public_ip}\""
			[[ $? == 0 ]] && { echo "${work_domain}: Ok"; break; }
			echo
			echo "The domain ${work_domain} does not resolve to the public IP of this server (${public_ip})"
			echo
			FAILED_CHECK=1;break
		done
		[[ ${FAILED_CHECK} -eq 1 ]] && break
	done
}

check_os() {
	# Detect OS
	if grep -qs "ubuntu" /etc/os-release; then
		os="ubuntu"
		os_version=$(
			grep 'VERSION_ID' /etc/os-release | \
				cut -d '"' -f 2 | tr -d '.'
		)

		# Set the dependencies for Ubuntu
		# TODO: Use this to declare different dependencies for different OSes
		REQUIRED_PACKAGES=(
			software-properties-common
			certbot
			dnsutils
			curl
			git
			python3
			python3-setuptools
			python3-apt
			python3-pip
			python3-passlib
			python3-wheel
			python3-bcrypt
			aptitude
		)

	else
		echo "This installer seems to be running on an unsupported distribution."
		echo "Supported distros are Ubuntu 20.04 and 22.04"
		exit
	fi

	# Check if the Ubuntu version is too old
	[[ "${os}" == "ubuntu" && "${os_version}" -lt 2004 ]] && {
		echo "Ubuntu 20.04 or higher is required to use this installer."
		echo "This version of Ubuntu is too old and unsupported."
		exit
	}
}

check_root() {
	# Check if the user is root or not
	if [[ ${EUID} -ne 0 ]]; then
		if [[ -n "$1" ]]; then
			SUDO='sudo -E -H'
		else
			SUDO='sudo -E'
		fi
	else
		SUDO=''
	fi
}

clone_repo_galaxy() {
	# Clone the Ansible playbook
	[ -d "${ANSIBLE_WORK_DIR}" ] || {
		git clone "${GITHUB_REPO}" "${ANSIBLE_WORK_DIR}"
	}

	cd "${ANSIBLE_WORK_DIR}" && {
		ansible-galaxy install -r requirements.yml
	}
}

do_email_setup() {
	echo
	read -r -p "SMTP server: " email_smtp_host
	until [[ ${email_smtp_host} =~ ^[a-z0-9\.]+$ ]]; do
		[[ -n "${email_smtp_host}" ]] && echo "Invalid SMTP server"
		read -r -p "SMTP server: " email_smtp_host
	done
	echo

	read -r -p "SMTP port [465]: " email_smtp_port
	email_smtp_port=${email_smtp_port:-465}
	until [[ ${email_smtp_port} =~ ^[0-9]+$ ]]; do
		echo
		echo "Invalid SMTP port"
		echo
		read -r -p "SMTP port [465]: " email_smtp_port
	done
	echo

	read -r -p "SMTP login: " email_login
	until [[ -n ${email_login} ]]; do
		echo
		echo "The login is empty"
		echo
		read -r -s -p "SMTP login: " email_login
	done
	echo

	read -r -s -p "SMTP password: " email_password
	until [[ -n ${email_password} ]]; do
		echo
		echo "The password is empty"
		echo
		read -r -s -p "SMTP password: " email_password
	done
	echo

	echo
	read -r -p "'From' e-mail [${email_login}]: " email
	email=${email:-$email_login}
	until [[ -n ${email} ]]; do
		echo
		echo "The e-mail is empty"
		echo
		read -r -s -p "'From' e-mail: " email
	done

	echo
	read -r -p "'To' e-mail [${email}]: " email_recipient
	email_recipient=${email_recipient:-$email}
	until [[ -n ${email_recipient} ]]; do
		echo
		echo "The e-mail is empty"
		echo
		read -r -s -p "'To' email: " email_recipient
	done

	(
	echo "email_smtp_host: \"${email_smtp_host}\""
	echo "email_smtp_port: \"${email_smtp_port}\""
	echo "email_login: \"${email_login}\""
	echo "email: \"${email}\""
	echo "email_recipient: \"${email_recipient}\""
	) >> "${CUSTOM_FILE}"

	echo "email_password: \"${email_password}\"" >> "${SECRET_FILE}"

}

get_authoritive_nameservers() {
	# Find name servers for a domain name
	# - may have sub domains to remove to get to the name servers
	local DOMX=${1}
	local NEW_DOMX
	while :
	do
		mapfile -t NAMESERVERS < <(
			dig -t ns "${DOMX}"    |
				grep -Ev '(^;|^$)' |
				column -t          |
				awk '$4 == "NS" {print $5}'
		)
		[[ ${#NAMESERVERS[@]} -gt 0 ]] && break
		NEW_DOMX="${DOMX#*.}"
		[[ ${DOMX} == "${NEW_DOMX}" ]] && {
			# This should never happen, but it will if the TLD is invalid
			# OR there are no name servers setup for the domain name
			# Besides, if we get to the TLD, we are already in trouble.
			echo "bad TLD for given domain name OR missing authoritive name servers: ${DOMX}"
			exit
		}
		DOMX="${NEW_DOMX}"
	done
}

install_dependencies() {
	# Disable interactive apt functionality
	export DEBIAN_FRONTEND=noninteractive

	# Update apt database, update all packages and install Ansible + dependencies
	check_root
	${SUDO} apt update -y

	yes | ${SUDO} apt-get -o Dpkg::Options::="--force-confold" -fuy dist-upgrade

	yes | ${SUDO} apt-get -o Dpkg::Options::="--force-confold" -fuy install \
		"${REQUIRED_PACKAGES[@]}"

	yes | ${SUDO} apt-get -o Dpkg::Options::="--force-confold" -fuy autoremove

	# Extra packages for arm64 (aarch64)
	[[ $(uname -m) == "aarch64" ]] && {
		${SUDO} yes | apt install -y \
			gcc python3-dev libffi-dev libssl-dev make
	}

	# Enable interactive apt functionality again
	export DEBIAN_FRONTEND=

	# Install Ansible
	check_root "-H"
	${SUDO} pip3 install ansible~=6.2
	check_root
}

set_permissions() {
	# Set secure permissions for the Vault file
	[[ -f "${SECRET_FILE}" ]] && {
		clear
		echo "WARNING: ${SECRET_FILE} already exists"
		echo "Running this script will overwrite its contents"
		read -n 1 -s -r -p "Press [Enter] to continue or Ctrl+C to abort "
		echo
	}
	touch "${SECRET_FILE}"
	chmod 600 "${SECRET_FILE}"

	# Permissions are not critical with the CUSTOM_FILE
	# - secrets are not kept in this file
	touch "${CUSTOM_FILE}"
}

ssh_keys_aws() {
	clear
	read -r -p "Are you running this script on an AWS EC2 instance? [y/N]: " aws_ec2
	until [[ ${aws_ec2} =~ ^[yYnN].*$ ]]; do
		echo "${aws_ec2}: invalid selection."
		read -r -p "Are you running this script on an AWS EC2 instance? [y/N]: " aws_ec2
	done
	if [[ "${aws_ec2}" =~ ^[yY].*$ ]]; then
		export AWS_EC2=true
		echo "aws_ec2: \"${aws_ec2}\"" >> "${CUSTOM_FILE}"
		echo
		echo "Please use the SSH keys that you specified in the AWS Management Console to log in to the server."
		echo "Also, make sure that your Security Group allows inbound connections on 51820/udp, 80/tcp and 443/tcp."
		echo
		read -n 1 -s -r -p "Press [Enter] to continue "
	fi
}

ssh_keys() {
	clear
	echo "Would you like to use an existing SSH key?"
	echo "Press 'n' if you want to generate a new SSH key pair"
	echo
	read -r -p "Use existing SSH key? [y/N]: " new_ssh_key_pair
	until [[ ${new_ssh_key_pair} =~ ^[yYnN].*$ ]]; do
		echo
		echo "${new_ssh_key_pair}: invalid selection."
		read -r -p "Use existing SSH key? [y/N]: " new_ssh_key_pair
	done

	if [[ "${new_ssh_key_pair}" =~ ^[yY].*$ ]]; then
		# NO checks done for public key....
		echo
		read -r -p "Please enter your SSH public key: " ssh_key_pair
		until [[ ${ssh_key_pair} =~ ^ssh-.+$ ]]; do
			echo
			echo "Invalid public key. Your SSH key should begin with \`ssh-\`"
			read -r -p "Please enter your SSH public key: " ssh_key_pair
		done
		echo "ssh_public_key: \"${ssh_key_pair}\"" >> "${CUSTOM_FILE}"
	fi
}


# Main
check_os
install_dependencies
clone_repo_galaxy
set_permissions

# Greeting
clear
echo "Welcome to ansible-easy-vpn!"
echo
echo "This script is interactive"
echo "If you prefer to fill in the ${CUSTOM_FILE} file manually,"
echo "press [Ctrl+C] to quit this script"
echo

# Username
echo "Enter your desired UNIX username"
read -r -p "Username: " username
until [[ ${username} =~ ^[a-z0-9]+$ && -n ${username} ]]; do
	echo
	echo "Invalid username"
	echo "Make sure the username only contains lowercase letters and numbers"
	read -r -p "Username: " username
done
echo "username: \"${username}\"" >> "${CUSTOM_FILE}"


# Password
clear
echo "Enter your user password"
echo "This password will be used for Authelia login, administrative access and SSH login"
while :
do
	user_password=
	until [[ ${#user_password} -lt 73 && -n ${user_password} ]]; do
		echo
		[[ ${#user_password} -gt 72 ]] && echo "The password is too long"
		[[ -z ${user_password} ]] && echo "The password is empty"
		read -s -r -p "Password: " user_password
	done
	user_password2=
	until [[ -n ${user_password2} ]]; do
		echo
		read -s -r -p "Repeat password: " user_password2
	done
	echo
	[[ "${user_password}" == "${user_password2}" ]] && break
	echo "The passwords don't match"
	echo
done

# Overwrite the secret file
echo "user_password: \"${user_password}\"" > "${SECRET_FILE}"


# Domain name
clear
echo "Enter your domain name"
echo "The domain name should already resolve to the IP address of your server"
echo "Make sure that 'wg' and 'auth' subdomains also point to that IP (not necessary with DuckDNS)"
echo
read -r -p "Domain name: " root_host
until [[ ${root_host} =~ ^[a-z0-9\.-]+$ && -n ${root_host} ]]; do
	echo "Invalid domain name"
	read -r -p "Domain name: " root_host
done

echo
echo "Checking if the domain name resolves to the IP of this server..."
# Check that @, wg and auth all resolve to the server's IP
while :
do
	check_domain_dns
	[[ ${FAILED_CHECK} -eq 0 ]] && break
	root_host_prev="${root_host}"
	read -r -p "Domain name [${root_host_prev}]: " root_host
	[[ -z ${root_host} ]] && root_host="${root_host_prev}"
	until [[ ${root_host} =~ ^[a-z0-9\.-]+$ && -n ${root_host} ]]; do
		echo "Invalid domain name"
		read -r -p "Domain name: " root_host
	done
done

# Issue a staging Let's Encrypt cert to make sure the server is reachable
check_certbot_dryrun
# Once everything checks out, save the domain name into the custom variables file
echo "root_host: \"${root_host}\"" >> "${CUSTOM_FILE}"

# Check if the user is running AWS and handle SSH key generation
check_aws

# E-Mail
clear
echo "Would you like to set up the e-mail functionality?"
echo "It will be used to confirm the 2FA setup and restore the password in case you forget it"
echo
echo "This is optional"
echo
read -r -p "Set up e-mail? [y/N]: " email_setup
until [[ ${email_setup} =~ ^[yYnN].*$ ]]; do
	echo "${email_setup}: invalid selection."
	read -r -p "Set up e-mail? [y/N]: " email_setup
done
[[ "${email_setup}" =~ ^[yY].*$ ]] && do_email_setup


# Generate and save the Authelia secrets
(
for _secret in jwt_secret session_secret storage_encryption_key
do
	echo "${_secret}: $(openssl rand -hex 23)"
done
) >> "${SECRET_FILE}"


# Encrypt the ${SECRET_FILE}
clear
echo "Encrypting the variables"
echo
ansible-vault encrypt "${SECRET_FILE}"
echo
echo "Success!"


# Ready to launch the playbook now!
read -r -p "Would you like to run the playbook now? [y/N]: " launch_playbook
until [[ ${launch_playbook} =~ ^[yYnN].*$ && -n ${launch_playbook} ]]; do
	echo "$launch_playbook: invalid selection."
	read -r -p "Would you like to run the playbook now? [y/N]: " launch_playbook
done
if [[ ${launch_playbook} =~ ^[yY].*$ ]]; then
	if [[ ${EUID} -ne 0 ]]; then
		echo
		echo "Please enter your current sudo password now"
		cd "${ANSIBLE_WORK_DIR}" && ansible-playbook -K run.yml
	else
		cd "${ANSIBLE_WORK_DIR}" && ansible-playbook run.yml
	fi
else
	echo
	echo "You can run the playbook by executing the following command"
	echo "cd \"${ANSIBLE_WORK_DIR}\" && ansible-playbook run.yml"
fi

exit 0
