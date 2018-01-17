#!/bin/bash
#
GROUP_VARS_FILE=group_vars/all.yml

function do_we_have_ip_addresses {
   for node in haproxy-0 haproxy-1 master-0 worker-0; do
       grep ${node} ${GROUP_VARS_FILE} | grep -E "([0-9]{1,3}\.){3}[0-9]{1,3}" > /dev/null
       if [[ $? -ne 0 ]]; then
           echo "ERROR: ${node} does not have a valid IP address."
           echo "(This can be caused if you have another stack in your tenancy, stealing your IP Addresses.)"
           exit 1
       fi
   done
}

do_we_have_ip_addresses
