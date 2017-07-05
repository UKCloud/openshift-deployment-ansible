#!/bin/bash

ansible-playbook -i localhost initalise.yaml
ansible-playbook setup_keepalived.yaml
ansible-playbook post_config_haproxy.yaml
ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/byo/config.yml
ansible-playbook setup_storage_classes.yml
