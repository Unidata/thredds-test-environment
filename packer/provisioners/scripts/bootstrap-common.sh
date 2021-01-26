#!/usr/bin/bash
set -ex

ANSIBLE_CONFIG_DIR=/ansible_config
ANSIBLE_CONFIG=${ANSIBLE_CONFIG_DIR}/ansible.cfg

# Check that we are root, and if not, use sudo to run commands.
SUDO_CMD=""
if [ "$EUID" -ne 0 ]; then
    SUDO_CMD="sudo"
fi

# Update apt package index.
${SUDO_CMD} apt update --yes

# General upgrade of environment.
${SUDO_CMD} apt upgrade --yes

# Need to set timezone before running the other apt commands, otherwise we
# risk getting stuck at a prompt asking us to set the timezone interactivly
DEBIAN_FRONTEND="noninteractive" TZ="Etc/UTC" ${SUDO_CMD} apt install --yes tzdata

# Once the ansiuble PPA has builds for 20.04, uncomment the next sections
# to install ansible using it.
# Add ansible ppa.
# https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#installing-ansible-on-ubuntu
#${SUDO_CMD} apt install --yes software-properties-common
#${SUDO_CMD} apt-add-repository --yes --update ppa:ansible/ansible

# Install ansible.
${SUDO_CMD} apt install --yes ansible

# Show ansible version info on console.
ansible --version

# Configure ansible to show the time it takes to run each task (need to write
# a custom ansible config file).
${SUDO_CMD} mkdir ${ANSIBLE_CONFIG_DIR}
echo "[defaults]" | ${SUDO_CMD} tee ${ANSIBLE_CONFIG} 
echo "callback_whitelist = profile_tasks" | ${SUDO_CMD} tee -a ${ANSIBLE_CONFIG} 
${SUDO_CMD} chmod 444 ${ANSIBLE_CONFIG}
${SUDO_CMD} cat ${ANSIBLE_CONFIG}
