#!/bin/bash

# Read password from command args. If it is absent, generate a new one.
# Intended to allow test pipeline to use a known password.
if [[ "$1" == "" ]]; then
    ADMIN_PASSWORD=$(openssl rand -base64 20 | cut -d= -f1)
else
    ADMIN_PASSWORD=$1
fi

ADMIN_USER="admin"

# Store the password
echo "${ADMIN_USER}:${ADMIN_PASSWORD}" > /home/cloud-user/passwords.txt;

# Turn the plain-text password into an htpasswd password
ansible -i localhost, localhost -c local -m htpasswd  -a "path=./tmp_htpasswd name=${ADMIN_USER} password=${ADMIN_PASSWORD}"

# Store the encrypted password in the env, so the initialisation role can read it.
export OPENSHIFT_PASSWORD=$(cut -d: -f2 tmp_htpasswd)
rm tmp_htpasswd

# Build the openshift-ansible-hosts file for use in the next play,
# and install bind-utils
ansible-playbook -i localhost, -c local bastion.yml

ansible-playbook --private-key ~/id_rsa_jenkins -i openshift-ansible-hosts site.yml
