#!/bin/bash

#
# will be doing a "stack update" which calls a different bit of the HEAT.
# update params in environment file, then run "openstack stack update" in the
# Heat.
#
#

[[ -e group_vars/all.yml ]] || (echo "ERROR: File group_vars/all.yml is missing" && exit)
[[ -e openshift-ansible-hosts ]] || (echo "ERROR: File openshift-ansible-hosts is missing" && exit)

# Test if there are any additional hosts, and
# build the inventory file for the upscale.
num_hosts_new=$(grep 'worker-[0-9][0-9]*' group_vars/all.yml | wc -l)
num_hosts_old=$(grep 'worker-[0-9][0-9]*' openshift-ansible-hosts | wc -l)

if (( num_hosts_new >  num_hosts_old )) ; then
    echo "Upscale needed: Number of additional hosts: $(expr ${num_hosts_new} - ${num_hosts_old} )"
else
    echo "Nothing to do"
    exit
fi

echo "Building inventory for upscale"
tools/create-upscale-inventory.py

echo "Performing upscale..."
ansible-playbook --private-key ~/id_rsa_jenkins -i openshift-ansible-hosts-upscale upscale.yml

# Rebuild the inventory file.
ansible-playbook -i localhost, -c local bastion.yml

rm openshift-ansible-hosts-upscale
