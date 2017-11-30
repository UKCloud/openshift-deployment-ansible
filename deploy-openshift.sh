#!/bin/bash

if [[ -n $(ansible --version | grep 2.4.1.0) ]] ; then
    echo "Downgrading from non-working Ansible version."
    sudo yum remove -y ansible-2.4.1.0-1.el7.noarch
    sudo yum install -y ansible-2.4.0.0-5.el7.noarch atomic-openshift-utils atomic-openshift-excluder atomic-openshift-clients
fi


# build the openshift-ansible-hosts file for use in the next play.
ansible-playbook -i localhost, -c local bastion.yml

ansible-playbook --private-key ~/id_rsa_jenkins -i openshift-ansible-hosts site.yml
