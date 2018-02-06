#!/bin/bash

# Logging into openshift in order to run oc commands later in script.

oc login -u $ADMIN_USERNAME -p $ADMIN_PASSWORD

# Variables to store state of master nodes
master0state=$(oc get node | grep master-0 | awk '{ print $2 }' | cut -d , -f 1)
master1state=$(oc get node | grep master-1 | awk '{ print $2 }' | cut -d , -f 1)
master2state=$(oc get node | grep master-2 | awk '{ print $2 }' | cut -d , -f 1)

echo Script starting this will take around 2 minutes to complete.
echo

# Creates symbolic link to ansible config file in order to send log output to ~/ansible.log
if [[ ! -L ansible.cfg ]]
then
	ln -s ../../ansible.cfg ansible.cfg
fi

# Checks the master nodes are in state "Ready" and exits script if not. If they are it runs the ansible playbooks to poll the API and hard reboot the master nodes in turn.
if [[ $master0state != Ready ]] || [[ $master1state != Ready ]] || [[ $master2state != Ready ]]
then
	echo "One of more master nodes is not in state "Ready" please correct this and run the script again." 
	echo
	exit 1
else
	ansible-playbook poll.yml > /dev/null 2>&1 &
	sleep 2
	ansible-playbook node_rotate.yml > /dev/null 2>&1 & 
fi

# Loop to wait until the node_rotate playbook is finished and allow the poll playbook to be killed once it is.
until [[ -z $(ps -ef | grep "/[u]sr/bin/ansible-playbook node_rotate.yml" | awk '{ print $2}') ]]
do
	sleep 1
done

# Writes output of poll playbook to haproxytest.log determines this from the playbook PID.
cat ~/ansible.log | grep $(ps -ef | grep "/[u]sr/bin/ansible-playbook poll.yml" | awk '{ print $2}' | head -1) > haproxytest.log

#Kills poll playbook.
ps -ef | grep "/[u]sr/bin/ansible-playbook poll.yml" | awk '{ print $2}' | xargs -x kill -9

#Uses regex to filter haproxytest.log for the information needed and then write it back to the log.
perl -ne 'print if /item=\d/' haproxytest.log | awk '{ print $1 " " $2 " connection " $6}' > connect.log

rm haproxytest.log

#Prints out total downtime in seconds.
echo
echo $(cat connect.log | grep failed | awk '{ print $2 }' | cut -d ":" -f 3 | sed s/,/./g | awk 'p{print $0-p}{p=$0}' | awk '{total = total + $1}END{print "There was a total of " total " seconds downtime"}') | tee -a connect.log
echo
echo Results of script saved in connect.log
echo
echo "End of script." 
