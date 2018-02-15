#!/bin/bash
#
# Reboot a node in the cluster.
#
# This script reboots the specified node in the cluster using the openstack
# command line tools. Authentication credentials are available in the
# Ansible inventory file.
# Once the reboot has been executed, this script polls for the state, first
# asking Openstack for the state of the
#
# The Ansible openstack module (os_server_action) requires the "shade" module,
# whereas we already have access to the "openstack" command line. Therefore, 
# we're doing this in bash.
#
# It is acceptable to reboot master-0, and haproxy nodes.
#
# TODO: Parameterise whether to do a hard or soft reboot
#       e.g. openstack server reboot --hard SERVER
#

# Work out where we are, so we can be exec'd from anywhere.
here=$(dirname "$0")

# openstack params are in the inventory file.
inventory=${here}/../openshift-ansible-hosts

# Work out the suffix.
localDomainSuffix=$(grep master-0 ${inventory} | head -1 | cut -d. -f2)


# -----------------------------------------------
# Read a variable from the inventory file and print the result to stdout.
#
# Args:
#    $1: the name of the variable to read.
# Returns:
#    Nothing. Execute within `` or $() to capture the value from stdout.
#
read_var() {
    var_name="$1"
    grep "${var_name}" "${inventory}" | awk -F= '{print $2}'
}

# -----------------------------------------------
# Set the environment variables that the 
# "openstack" command needs.
#
# Args:
#     None
# Returns:
#     Nothing
#
set_openstack_vars() {
    export OS_AUTH_URL=$(read_var openshift_cloudprovider_openstack_auth_url)
    export OS_REGION_NAME=$(read_var openshift_cloudprovider_openstack_region)
    export OS_TENANT_ID=$(read_var openshift_cloudprovider_openstack_tenant_id)
    export OS_TENANT_NAME=$(read_var openshift_cloudprovider_openstack_tenant_name)
    export OS_USERNAME=$(read_var openshift_cloudprovider_openstack_username)
    export OS_PASSWORD=$(read_var openshift_cloudprovider_openstack_password)
}

# -----------------------------------------------
# Get an array of all the nodes according to the inventory file
#   - cut removes host-specific variables from the end
#   - grep -v removes a variable definition (has to be after the cut)
#   - then remove duplicates with sort | uniq 
#
# Args:
#     None
# Returns:
#     The list of nodes (Execute with $() to capture value)
get_all_nodes() {
    grep "${localDomainSuffix}" ${inventory} | cut -d' ' -f1 | grep -v = | sort | uniq
}

# -----------------------------------------------
# Print out the list of all nodes
list_all_nodes() {
    echo "Valid node names are:"
    echo "---------------------"
    get_all_nodes
    echo ""
}

# -----------------------------------------------
# Repeatedly query openstack until the specified node
# comes back online
#
# Args:
#     the name of the variable to hold the result.
# Returns:
#     The status of the node; any valid status from
#      `openstack server list`. Typically, either "ACTIVE"
#     if it came back online within 10 minutes, or "REBOOT"
#     if it timed out.
#
wait_for_server_online() {
    local  __resultvar=$1
    local count=0
    local os_node_status="unknown"
    while [[ "$os_node_status" != "ACTIVE" ]]; do
        local st=$(openstack server list -c Name -c Status -f value | grep "${targetNode}")
        echo ${st}
        os_node_status=$(echo ${st} | cut -d' ' -f2)
        sleep 5
        count=$(($count+1))
        if [[ ${count} -gt 120 ]]; then
            # > 10 minutes (120*5s). bomb out.
            echo "Timeout. No longer polling for Active state."
            break
        fi
    done
    eval ${__resultvar}="'${os_node_status}'"
}

# -----------------------------------------------
# Repeatedly query openshift until the specified node
# is ready for operation.
#
# NOTE: You should `wait_for_server_online` first to
# ensure the OS is running.
#
# Args:
#     None
# Returns:
#     The status of the node as(capture with $?)
#
wait_for_node_ready() {
    local  __resultvar=$1
    local count=0
    local oc_node_status="unknown"
    while [[ "${oc_node_status}" != "Ready" ]]; do
        local st=$(ssh ${master} oc get nodes | grep "${targetNode}")
        echo ${st} | awk '{print $1,$2}'

        # Master nodes have an additional parameter after the status.
        # (SchedulingDisabled). Remove it from the status line
        oc_node_status=$(echo ${st} | awk '{print $2}' | sed 's/,SchedulingDisabled//')

        sleep 5
        count=$(($count+1))
        if [[ ${count} -gt 120 ]]; then
            # > 10 minutes (120*5s). bomb out.
            echo "Timeout. No longer polling for Ready state."
            break
        fi
    done
    eval ${__resultvar}="'${oc_node_status}'"

}

# -----------------------------------------------


targetNode="$1"

master="master-0.${localDomainSuffix}"

# Is the target node master-0? If so, we need to
# use a different master to check the state
if [[ "$targetNode" == "$master" ]]; then
    master="master-1.${localDomainSuffix}"
fi

if [[ -z "${targetNode}" ]]; then
    echo "Reboot a specific node."
    echo "Usage: $0 <node-to-reboot>"
    echo ""
    list_all_nodes
    exit 1
fi

# Does the supplied node exist?
valid_nodes=$(get_all_nodes)
if [[ -z "$(echo ${valid_nodes} | grep ${targetNode})" ]]; then
    echo "ERROR: Target '${targetNode}' is not a valid node"
    echo ""
    list_all_nodes
    exit 2
fi

# Set the environment variables needed to authenticate to Openstack.
set_openstack_vars

echo ""
echo "REBOOTING '${targetNode}'"
openstack server reboot "${targetNode}"

echo "Waiting for '${targetNode}' to come back online..."
echo -n "Should take under 5 minutes. Time now is: "
date +%H:%M:%S

# poll to see if it's active - put the answer into $node_status
node_status=""
wait_for_server_online node_status


if [[ -n "$(echo ${targetNode} | grep haproxy)" ]]; then
    echo "INFO: Cannot determine state of haproxy application."
    node_status="Ready"
else
    if [[ "${node_status}" == "ACTIVE" ]]; then
        # openstack says the node is 'ACTIVE' which means the OS is
        # running, but it needs a bit longer before the node is
        # back in the cluster.

        # poll to see if it's Ready - put the answer into $node_status
        wait_for_node_ready node_status
    fi
fi

if [[ "${node_status}" == "Ready" ]]; then
    echo ""
    echo "DONE: Node '${targetNode}'  successfully rebooted"
fi
