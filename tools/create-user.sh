#!/bin/bash

username=$1
password=$2
debug=0

if [[ -z $username ]] || [[ -z $password ]]; then
  echo -e "help: This script will add users to htpasswd for OpenShift.\n\n"
  echo -e "usage: $0 <username> <password>\n"
  exit 1
else
  if [[ $debug != 0 ]]; then
    ansible-playbook --private-key ~/id_rsa_jenkins -i ../openshift-ansible-hosts -e USERNAME=$username -e PASSWORD=$password playbooks/htpassword.yaml -vv
  else
    ansible-playbook --private-key ~/id_rsa_jenkins -i ../openshift-ansible-hosts -e USERNAME=$username -e PASSWORD=$password playbooks/htpassword.yaml
  fi
fi
