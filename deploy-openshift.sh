#!/bin/bash


ansible-playbook --private-key ../id_rsa_jenkins -i localhost initalise.yaml -vvv
ansible-playbook --private-key ../id_rsa_jenkins -i openshift-ansible-hosts setup_keepalived.yaml
ansible-playbook --private-key ../id_rsa_jenkins -i openshift-ansible-hosts setup_haproxy.yaml
ansible-playbook --private-key ../id_rsa_jenkins -i openshift-ansible-hosts /usr/share/ansible/openshift-ansible/playbooks/byo/config.yml
ansible-playbook --private-key ../id_rsa_jenkins -i openshift-ansible-hosts setup_storage_classes.yml
