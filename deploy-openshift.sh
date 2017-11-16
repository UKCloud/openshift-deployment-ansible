#!/bin/bash

# Temporary: Patch the openshift-ansible install_cassandra.yaml for version 3.6.173.0.48-1
yum list openshift-ansible 2>&1 | grep 3.6.173.0.48-1 >/dev/null
if [ $? -eq 0 ]; then
	curl https://raw.githubusercontent.com/openshift/openshift-ansible/80d141b5d60da9afbd3c02350933c090d1839c46/roles/openshift_metrics/tasks/install_cassandra.yaml > /tmp/install_cassandra.yaml
	sudo cp /tmp/install_cassandra.yaml /usr/share/ansible/openshift-ansible/roles/openshift_metrics/tasks/

	echo "/usr/share/ansible/openshift-ansible/roles/openshift_metrics/tasks/install_cassandra.yaml has been tweaked"
	ls -l /usr/share/ansible/openshift-ansible/roles/openshift_metrics/tasks/install_cassandra.yaml
fi

# End of temporary hack

# build the openshift-ansible-hosts file for use in the next play.
ansible-playbook -i localhost, -c local bastion.yml

ansible-playbook --private-key ~/id_rsa_jenkins -i openshift-ansible-hosts site.yml
