#!/bin/bash

# build the openshift-ansible-hosts file for use in the next play.
ansible-playbook -i localhost, -c local bastion.yml

ansible-playbook --private-key ~/id_rsa_jenkins -i openshift-ansible-hosts site.yml
