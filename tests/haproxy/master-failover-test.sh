#!/bin/bash

# Ensure admin username and admin password are passed to script in Jenkinsfile.
if  [[ -z $1 ]] || [[ -z $2 ]]
then
	echo "Usage $0 <admin username> <admin password>"
	exit 1
fi

# Move to correct directory to run commands with relative paths
cd /usr/share/ansible/openshift-deployment-ansible/tests/haproxy 

# Logging into openshift in order to run oc commands later in script. 
DOMAINSUFFIX=$(cat ../../group_vars/all.yml | grep domainSuffix | awk '{print $2}')

oc login -u $1 -p $2 --server="https://ocp.$DOMAINSUFFIX:8443" --insecure-skip-tls-verify

# Storing master node names (easiest way to do this and ensure future proof for node changes)
masters="$(oc get nodes -o custom-columns=NAME:metadata.name --no-headers=true | grep master)"
master0name=$("${masters}" | grep -- -0.)
master1name=$("${masters}" | grep -- -1.)
master2name=$("${masters}" | grep -- -2.)

# Variables to store state of master nodes
master0state=$(oc get node | grep $master0name | awk '{ print $2 }' | cut -d , -f 1)
master1state=$(oc get node | grep $master1name | awk '{ print $2 }' | cut -d , -f 1)
master2state=$(oc get node | grep $master2name | awk '{ print $2 }' | cut -d , -f 1)

# Create symbolic link to ansible config file in order to send log output to ~/ansible.log
if [[ ! -L ansible.cfg ]]
then
	ln -s ../../ansible.cfg ansible.cfg
fi

# Check the master nodes are in state "Ready" and exit the script if not. 
# If they are it runs the ansible playbooks to poll the API and hard reboot the master nodes in turn.
if [[ $master0state != Ready ]] || [[ $master1state != Ready ]] || [[ $master2state != Ready ]]
then
	echo "One of more master nodes is not in state "Ready" please correct this and run the script again." 
	echo
	exit 1
else
	ansible-playbook poll.yml &
	sleep 2
	ansible-playbook node_rotate.yml & 
fi
 
# Wait until the node_rotate playbook is finished and allow the poll playbook to be killed once it is.
until [[ -z $(ps -ef | grep "/[u]sr/bin/ansible-playbook node_rotate.yml" | awk '{ print $2}') ]]
do
	sleep 1
done
 
# Write output of poll playbook to haproxytest.log determines this from the playbook PID.
cat ~/ansible.log | grep $(ps -ef | grep "/[u]sr/bin/ansible-playbook poll.yml" | awk '{ print $2}' | head -1) > haproxytest.log
 
# Kill poll playbook.
ps -ef | grep "/[u]sr/bin/ansible-playbook poll.yml" | awk '{ print $2}' | xargs -x kill -9
 
# Filter haproxytest.log for the information needed and then write it back to the log.
perl -ne 'print if /item=\d/' haproxytest.log | awk '{ print $1 " " $2 " connection " $6}' > connect.log
 
rm haproxytest.log
 
# Print out total downtime in seconds.
echo
echo $(cat connect.log | grep failed | awk '{ print $2 }' | cut -d ":" -f 3 | sed s/,/./g | awk 'p{print $0-p}{p=$0}' | awk '{total = total + $1}END{print "There was a total of " total " seconds downtime"}') | tee -a connect.log
echo
echo Results of script saved in connect.log
echo
echo "End of script." 

