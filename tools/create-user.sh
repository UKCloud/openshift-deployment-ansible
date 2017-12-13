#!/bin/bash

username=$1
password=$2
debug=0

if [[ -z $username ]] || [[ -z $password ]]; then
  echo -e "help: This script will add users to htpasswd for OpenShift.\n\n"
  echo -e "usage: $0 <username> <password>\n"
  exit 1
fi

privkey=~/id_rsa_jenkins
inventory=../openshift-ansible-hosts
playbook=playbooks/htpassword.yaml
extras=""

if [[ $debug != 0 ]]; then
    extras="-vv"
fi

ansible-playbook --private-key $privkey -i $inventory -e USERNAME=$username -e PASSWORD=$password $extras $playbook