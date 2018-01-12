#!/bin/bash

ansible -i localhost, localhost  -m yum -b -a 'name=* state=latest'

echo "Now reboot the Bastion host"
echo "sudo reboot --reboot"
