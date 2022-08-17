#!/bin/bash -ue
# A bash script that prepares the OS
# before running the Ansible playbook
ANSIBLE_WORK_DIR="${HOME}/ansible-easy-vpn"
GITHUB_REPO="https://github.com/notthebee/ansible-easy-vpn"

check_aws() {
	# Check if we're running on an AWS EC2 instance
	set +e
	aws=$(curl -m 5 -s http://169.254.169.254/latest/meta-data/ami-id)

	if [[ "${aws}" =~ ^ami.*$ ]]; then
		ssh_keys_aws
	else
		ssh_keys_non_aws
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
	echo "OK"
}

check_os() {
	# Detect OS
	if grep -qs "ubuntu" /etc/os-release; then
		os="ubuntu"
		os_version=$(
			grep 'VERSION_ID' /etc/os-release | \
				cut -d '"' -f 2 | tr -d '.'
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

do_email_setup() {
	echo
	email_smtp_host=
	until [[ ${email_smtp_host} =~ ^[a-z0-9\.]*$ ]]; do
		[[ -n "${email_smtp_host}" ]] && echo "Invalid SMTP server"
		read -r -p "SMTP server: " email_smtp_host
	done
	echo
	read -r -p "SMTP port [465]: " email_smtp_port
	email_smtp_port=${email_smtp_port:-465}
	echo
	read -r -p "SMTP login: " email_login
	echo
	local email_password=
	until [[ -n ${email_password} ]]; do
		[[ -z ${email_password} ]] && echo "The password is empty"
		read -r -s -p "SMTP password: " email_password
	done
	echo
	echo
	read -r -p "'From' e-mail: " email
	[[ -n ${email} ]] && {
		echo "email: \"${email}\"" >> "${CUSTOM_FILE}"
	}

	read -r -p "'To' e-mail: " email_recipient
	[[ -n "${email_recipient}" ]] && {
		echo "email_recipient: \"${email_recipient}\"" >> "${CUSTOM_FILE}"
	}

	echo "email_smtp_host: \"${email_smtp_host}\"" >> "${CUSTOM_FILE}"
	echo "email_smtp_port: \"${email_smtp_port}\"" >> "${CUSTOM_FILE}"
	echo "email_login: \"${email_login}\"" >> "${CUSTOM_FILE}"

	if [ -z "${email_password+x}" ]; then
		echo
	else 
		# SECRET_FILE setup previously, save the secret
		echo "email_password: \"${email_password}\"" >> "${SECRET_FILE}"
	fi

}

get_ip_list() {
	# variable 1 is the main domain
	# variable 2 if present is (sub) host to query, falls back to $1
	local main_domain="${1}"
	local query_domain
	if [[ $# -eq 1 ]]; then
		query_domain="${1}"
	else
		query_domain="${2}"
	fi

	declare -a NAMESERVERS=(
		dig -t ns +short "${main_domain}"
	)
	# There should always be at least 2 nameservers, choose one randomly
	DNS_HOST_IDX=$(( RANDOM % ${#NAMESERVERS[@]} ))
	DNS_HOST=${NAMESERVERS["${DNS_HOST_IDX}"]}
	dig -t a +short @"${DNS_HOST}" "${query_domain}" | \
		grep '^[1-9]'  | tr '\n' ' '
}

install_packages_for_ansible_and_dependencies() {
	# Disable interactive apt functionality
	export DEBIAN_FRONTEND=noninteractive

	# Update apt database, update all packages and install Ansible + dependencies
	declare -a REQUIRED_PACKAGES=(
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

	# Enable interactive apt functionality (FWIW, not running apt again)
	export DEBIAN_FRONTEND=
}

install_and_setup_homedir_files() {
	# Do pip3 install in user's homedir (which may be root anyway)
	check_root "-H"
	${SUDO} pip3 install ansible~=6.2 &&

	check_root
	# Clone the Ansible playbook
	[ -d "${ANSIBLE_WORK_DIR}" ] || {
		git clone "${GITHUB_REPO}" "${ANSIBLE_WORK_DIR}"
	}

	cd "${ANSIBLE_WORK_DIR}" && {
		ansible-galaxy install -r requirements.yml
	}
}

ssh_keys_aws() {
	echo
	aws_ec2=
	until [[ ${aws_ec2} =~ ^[yYnN].*$ ]]; do
		[[ -n ${aws_ec2} ]] && echo "${aws_ec2}: invalid selection."
		read -r -p "Are you running this script on an AWS EC2 instance? [y/N]: " aws_ec2
	done
	if [[ "${aws_ec2}" =~ ^[yY].*$ ]]; then
		export AWS_EC2=true
		echo "aws_ec2: \"${aws_ec2}\"" >> "${CUSTOM_FILE}"
		echo
		echo "Please use the SSH keys that you specified in the AWS Management Console to log in to the server."
		echo "Also, make sure that your Security Group allows inbound connections on 51820/udp, 80/tcp and 443/tcp."
		echo
	fi
}

ssh_keys_non_aws() {
	echo
	echo "Would you like to use an existing SSH key?"
	echo "Press 'n' if you want to generate a new SSH key pair"
	echo
	new_ssh_key_pair=
	until [[ ${new_ssh_key_pair} =~ ^[yYnN].*$ ]]; do
		[[ -n ${new_ssh_key_pair} ]] && {
			echo "${new_ssh_key_pair}: invalid selection."
		}
		read -r -p "Use existing SSH key? [y/N]: " new_ssh_key_pair
	done
	echo "enable_ssh_keygen: true" >> "${CUSTOM_FILE}"

	[[ "${new_ssh_key_pair}" =~ ^[yY].*$ ]] && {
		# NO checks done for public key....
		echo
		read -r -p "Please enter your SSH public key: " ssh_key_pair
		echo "ssh_public_key: \"${ssh_key_pair}\"" >> "${CUSTOM_FILE}"
	}
}


# Main


check_os
install_packages_for_ansible_and_dependencies
install_and_setup_homedir_files


# Set secure permissions for the Vault file
SECRET_FILE="${HOME}/ansible-easy-vpn/secret.yml"
touch ${SECRET_FILE}
[[ -f "${SECRET_FILE}" ]] && {
	echo
	echo "WARNING:"
	echo "${SECRET_FILE} already exists..."
	echo
}
chmod 600 "${SECRET_FILE}"


# Permissions are not critical with the CUSTOM_FILE
# - secrets are not kept in this file
CUSTOM_FILE="${HOME}/ansible-easy-vpn/custom.yml"
touch ${CUSTOM_FILE}
[[ -f "${CUSTOM_FILE}" ]] && {
	echo
	echo "WARNING:"
	echo "${CUSTOM_FILE} already exists..."
	echo
}





clear
echo "Welcome to ansible-easy-vpn!"
echo
echo "This script is interactive"
echo "If you prefer to fill in the ${CUSTOM_FILE} file manually,"
echo "press [Ctrl+C] to quit this script"
echo
echo "Enter your desired UNIX username"
username=
until [[ ${username} =~ ^[a-z0-9]*$ && -n ${username} ]]; do
	[[ -n ${username} ]] && echo "Invalid username"
	echo "Make sure the username only contains lowercase letters and numbers"
	read -r -p "Username: " username
done
# First write to CUSTOM_FILE, old content will be lost
# - appending to file anyway, last entry will count, may end up using
#   sed method later to not have multiple entries to confuse things.
echo "username: \"${username}\"" >> "${CUSTOM_FILE}"


echo
echo "Enter your user password"
echo "This password will be used for Authelia login, administrative access and SSH login"
echo "Passwords longer trhan 72 bytes are not supported by OpenSSH private key format"
echo "Also, the password cannot be empty"
while :
do
	user_password=
	until [[ ${#user_password} -lt 73 && -n ${user_password} ]]; do
		echo
		[[ ${#user_password} -gt 72 ]] && echo "The password is too long"
		read -s -r -p "Password: " user_password
	done
	echo
	user_password2=
	until [[ -n ${user_password2} ]]; do
		echo
		read -s -r -p "Repeat password: " user_password2
	done
	echo
	[[ "${user_password}" == "${user_password2}" ]] && break
	echo "The passwords don't match"
done
# First write to SECRET_FILE, old content will be lost
echo "user_password: \"${user_password}\"" > "${SECRET_FILE}"


echo
echo
echo "Enter your domain name"
echo "The domain name should already resolve to the IP address of your server"
echo "Make sure that 'wg' and 'auth' subdomains also point to that IP (not necessary with DuckDNS)"
echo
root_host=
until [[ ${root_host} =~ ^[a-z0-9\.-]*$ && -n ${root_host} ]]; do
	[[ -n ${root_host} ]] && echo "Invalid domain name"
	read -r -p "Domain name: " root_host
done


echo
while :
do
	# Okay, a "list of IPs" probably doesn't make sense for WG,
	# but checking for the sub domains does make sense.
	# Probably can't do round robin DNS for WG ....
	# - but might be useful for other server types using this bootstrap
	public_ip=$(curl -s ipinfo.io/ip)
	domain_ip_list=$(get_ip_list "${root_host}")
	wg_domain_ip_list=$(get_ip_list "${root_host}" "wg.${root_host}")
	auth_domain_ip_list=$(get_ip_list "${root_host}" "auth.${root_host}")

	(
	echo "public_ip: ${public_ip}"
	echo "domain_ip_list: ${domain_ip_list}"
	echo "wg.domain_ip_list: ${wg_domain_ip_list}"
	echo "auth.domain_ip_list: ${auth_domain_ip_list}"
	) | column -t
	# The public_ip MUST be in the list of returned IPv4 addresses
	[[ ${domain_ip_list} =~ ${public_ip} && 
		${wg_domain_ip_list} =~ ${public_ip} &&
		${auth_domain_ip_list} =~ ${public_ip} ]] && break
	echo
	echo "The domain ${root_host} does not resolve to the public IP of this server (${public_ip})"
	echo
	root_host_prev="${root_host}"
	read -r -p "Domain name [${root_host_prev}]: " root_host
	[[ -z ${root_host} ]] && root_host="${root_host_prev}"
	echo
done

# Check certbot to make sure host is okay
check_certbot_dryrun
echo "root_host: \"${root_host}\"" >> "${CUSTOM_FILE}"

check_aws

echo
echo "Would you like to set up the e-mail functionality?"
echo "It will be used to confirm the 2FA setup and restore the password in case you forget it"
echo
echo "This is optional"
echo
email_setup=
until [[ ${email_setup} =~ ^[yYnN].*$ ]]; do
	[[ -n ${email_setup} ]] && echo "${email_setup}: invalid selection."
	read -r -p "Set up e-mail? [y/N]: " email_setup
done
[[ "${email_setup}" =~ ^[yY].*$ ]] && do_email_setup


# Save other secrets
(
for _secret in jwt_secret session_secret storage_encryption_key
do
	echo "${_secret}: $(openssl rand -hex 23)"
done
) >> "${SECRET_FILE}"


# Protect all the secrets in the SECRET_FILE
echo
echo "Encrypting the variables"
ansible-vault encrypt "${SECRET_FILE}"
echo
echo "Success!"


# Ready to launch the playbook now!
launch_playbook=
until [[ ${launch_playbook} =~ ^[yYnN].*$ && -n ${launch_playbook} ]]; do
	[[ -n ${launch_playbook} ]] && echo "$launch_playbook: invalid selection."
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
	echo "You can run the playbook by executing the following command"
	echo "cd \"${ANSIBLE_WORK_DIR}\" && ansible-playbook run.yml"
	exit
fi

exit 0
