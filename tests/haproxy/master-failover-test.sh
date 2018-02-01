#!/bin/bash

echo
echo -n "Warning: This script truncates ~/ansible.log before running in order to ouput a clean logfile at the end. The current contents of ~/ansible.log will be appended to ~/ansible.bk in case the contents need to be reviewed. Please confirm you would like to continue.. (y/n) "
read answer 

#truncates logfile before running. To enable output to be manipulated at the end.

if [[ $answer = y ]]
then 
	if [[ -a ~/ansible.log ]]
		then
			cat ~/ansible.log >> ~/ansible.bk
			truncate --size=0 ~/ansible.log
		else
			echo "~/ansible.log needs to exist. Please create file and run again."
			exit
	fi	
else
	echo "Script exiting..."
	exit
fi

if [ ! -L ansible.cfg ]
then
	ln -s /usr/share/ansible/openshift-deployment-ansible/ansible.cfg ansible.cfg
fi

#Variables to store master node IPs
master0ip=$(cat /etc/ansible/group_vars/all.yml | grep master-0 | awk '{ print $1 }' | sed s/://g)

master1ip=$(cat /etc/ansible/group_vars/all.yml | grep master-1 | awk '{ print $1 }' | sed s/://g)

master2ip=$(cat /etc/ansible/group_vars/all.yml | grep master-2 | awk '{ print $1 }' | sed s/://g)


#Variables to store atomic-openshift-master-api service status from master nodes. Used as check to ensure all services are running before they start getting taken down.
master0state=$(ssh -A $master0ip 'systemctl status atomic-openshift-master-api | head -n 3 | tail -n 1 | cut -d : -f 2 | cut -d " " -f 2')

master1state=$(ssh -A $master1ip 'systemctl status atomic-openshift-master-api | head -n 3 | tail -n 1 | cut -d : -f 2 | cut -d " " -f 2')

master2state=$(ssh -A $master2ip 'systemctl status atomic-openshift-master-api | head -n 3 | tail -n 1 | cut -d : -f 2 | cut -d " " -f 2')


#Running playbook that polls master cluster via http.
ansible-playbook /usr/share/ansible/openshift-deployment-ansible/poll.yml > /dev/null 2>&1 &


#Bash code to run service restarts on master nodes in turn. Will not run if services aren't running on all nodes. As ansible playbook is run in background there is a ps command to get PIDs and kill them if script has to exit.

if [[ $master0state != active ]] || [[ $master1state != active ]] || [[ $master2state != active ]]
then
	echo "The API service is not running on one or more master nodes. Please correct this and rerun the script."
	sleep 1
	ps -ef | grep "/[u]sr/bin/ansible-playbook /usr/share/ansible/openshift-deployment-ansible/poll.yml" | awk '{ print $2 }' | xargs -x kill -9
	exit
else
	if [[ "$(ssh -A $master0ip 'systemctl status atomic-openshift-master-api | head -n 3 | tail -n 1 | cut -d : -f 2 | cut -d " " -f 2')" = active ]]
	then
		sleep 10
		echo
		echo "Stopping API service on master-0"
        	ssh -A $master0ip 'sudo systemctl stop atomic-openshift-master-api'
        	sleep 20
		echo "Starting API service on master-0"
        	ssh -A $master0ip 'sudo systemctl start atomic-openshift-master-api'
	else
        	echo "Either the API service is not running on master-0 or the server is down. Please correct this before running script again."
		ps -ef | grep "/[u]sr/bin/ansible-playbook /usr/share/ansible/openshift-deployment-ansible/poll.yml" | awk '{ print $2 }' | xargs -x kill -9
		exit
	fi

	if [[ "$(ssh -A $master1ip 'systemctl status atomic-openshift-master-api | head -n 3 | tail -n 1 | cut -d : -f 2 | cut -d " " -f 2')" = active ]]
	then
		sleep 5
		echo "Stopping API service on master-1"
        	ssh -A $master1ip 'sudo systemctl stop atomic-openshift-master-api'
        	sleep 20
		echo "Starting API service on master-1"
        	ssh -A $master1ip 'sudo systemctl start atomic-openshift-master-api'
	else
        	echo "Either the API service is not running on master-1 or the server is down. Please correct this before running script again."
		ps -ef | grep "/[u]sr/bin/ansible-playbook /usr/share/ansible/openshift-deployment-ansible/poll.yml" | awk '{ print $2 }' | xargs -x kill -9
		exit
	fi

	if [[ "$(ssh -A $master2ip 'systemctl status atomic-openshift-master-api | head -n 3 | tail -n 1 | cut -d : -f 2 | cut -d " " -f 2')" = active ]]
	then
		sleep 5
		echo "Stopping API service on master-2"
        	ssh -A $master2ip 'sudo systemctl stop atomic-openshift-master-api'
        	sleep 20
		echo "Starting API service on master-2"
		echo
        	ssh -A $master2ip 'sudo systemctl start atomic-openshift-master-api'
	else
        	echo "Either the API service is not running on master-2 or the server is down. Please correct this before running script again."
		ps -ef | grep "/[u]sr/bin/ansible-playbook /usr/share/ansible/openshift-deployment-ansible/poll.yml" | awk '{ print $2 }' | xargs -x kill -9
		exit
	fi
fi

ps -ef | grep "/[u]sr/bin/ansible-playbook /usr/share/ansible/openshift-deployment-ansible/poll.yml" | awk '{ print $2 }' | xargs -x kill -9

perl -ne 'print if /item=\d/' ~/ansible.log | awk '{ print $1 " " $2 " connection " $6}' > haproxytest.log

# Following command could be used to output a total of the downtime experienced but if there was more than one block of downtime during the script the results would not add up correctly.
# cat haproxytest.log | grep failed | awk '{ print $2 }' | cut -d ":" -f 3 | sed s/,/./g | awk 'p{print $0-p}{p=$0}' | awk '{total = total + $1}END{print "There was a total of " total " seconds downtime"}'

echo
echo "Output of connection test written to haproxytest.log"
echo
echo $(cat haproxytest.log | grep failed | awk '{ print $2 }' | cut -d ":" -f 3 | sed s/,/./g | awk 'p{print $0-p}{p=$0}' | awk '{total = total + $1}END{print "There was a total of " total " seconds downtime"}')
echo
echo "End of script"
echo


