#!/bin/bash

PRIVKEY_ARG=''
if [[ -f ~/id_rsa_jenkins ]] ; then
    PRIVKEY_ARG='--private-key ~/id_rsa_jenkins'
fi

# Part 1, upgrading the Bastion host is in "upgrade_bastion.sh"

# Part 2: finish setting up Bastion.
# build the openshift-ansible-hosts file for use in the next play.
ansible-playbook -i localhost, -c local bastion.yml

# Part 3: Patch the system
ansible --private-key $PRIVKEY_ARG -i openshift-ansible-hosts  nodes -m atomic_host -b -a "revision=latest"
ansible --private-key $PRIVKEY_ARG -i openshift-ansible-hosts  loadbalancers -m yum -b -a 'name=* state=latest'

# Part 4: Reboot Masters, Workers and Loadbalancers
ansible --private-key $PRIVKEY_ARG -i openshift-ansible-hosts  nodes -b -a "reboot"
ansible --private-key $PRIVKEY_ARG -i openshift-ansible-hosts  loadbalancers -b -a "reboot"

# Part 5: Configure the rest of the system
ansible-playbook $PRIVKEY_ARG ~/id_rsa_jenkins -i openshift-ansible-hosts site.yml
