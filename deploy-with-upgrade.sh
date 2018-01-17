#!/bin/bash
#
# Deploy an Openshift cluster by running the Ansible Playbooks.
#
# If called with no args, the initial user is assumed to be "admin",
# and a password is generated.
#
# Optional args: (intended to allow the test pipeline to supply known credentials)
#    $1 - username of the admin user
#    $2 - password for the admin user
#    $3 - username of an additional user
#    $4 - password for the additional user
#
# If $1 is supplied, $2 must be supplied.
# if $3 is supplied, $4 must also be supplied.
# All optional args are positional.
#
# TODO: merge with deploy-openshift.sh

PRIVKEY_ARG=''
if [[ -f ~/id_rsa_jenkins ]] ; then
    PRIVKEY_ARG='--private-key ~/id_rsa_jenkins'
fi

if [[ "$1" == "" && "$2" == "" ]]; then
    ADMIN_USER="admin"
    ADMIN_PASSWORD=$(openssl rand -base64 20 | cut -d= -f1)
else
    ADMIN_USER=$1
    ADMIN_PASSWORD=$2
fi


# Store the password
echo "SHELL [store and encrypt admin password] ..."
echo "${ADMIN_USER}:${ADMIN_PASSWORD}" > /home/cloud-user/passwords.txt;

# Turn the plain-text password into an htpasswd password
ansible -i localhost, localhost -c local -m htpasswd  -a "path=./tmp_htpasswd name=${ADMIN_USER} password=${ADMIN_PASSWORD}"

# Store the encrypted password in the env, so the initialisation role can read it.
export OPENSHIFT_PASSWORD=$(cut -d: -f2 tmp_htpasswd)
rm tmp_htpasswd

# Build the openshift-ansible-hosts file for use in the next play,
# and install bind-utils
ansible-playbook -i localhost, -c local bastion.yml

# Perform the deployment
ansible-playbook $PRIVKEY_ARG -i openshift-ansible-hosts site.yml

# Create an additional user if $3 and $4 are supplied
if [[ "$3" != "" && "$4" != "" ]]; then
    echo "SHELL [create secondary user] ..."
    (cd tools; ./create-user.sh "$3" "$4")
    echo "$3:$4" >> /home/cloud-user/passwords.txt
fi

# Upgrade the Bastion Host
if [[ -n $(grep doUpgrades group_vars/all.yml |grep True) ]]; then
    echo ""
    echo "Please reboot the bastion host as soon as practical with the following:"
    echo "     sudo reboot --reboot"
    echo ""

fi
