#!/bin/bash

ansible-playbook bastion.yml
ansible-playbook --private-key ~/id_rsa_jenkins -i openshift-ansible-hosts site.yml
