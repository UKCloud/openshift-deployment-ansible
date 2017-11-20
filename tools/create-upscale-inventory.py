#!/usr/bin/env python
"""
Construct the new inventory file to add new workers

writes to a file called "openshift-ansible-hosts-upscale"
"""

import argparse
import re
import os
import yaml

from six.moves.configparser import ConfigParser

from ansible.inventory.manager import InventoryManager
from ansible.parsing.dataloader import DataLoader

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=


class UpscalingMasterNodeException(Exception):
    """ An exception raised if we find we're trying to add
    a Master (because this isn't supported at present)"""


class AnsibleInventory(ConfigParser):
    def __init__(self, filename=None):
        # ConfigParser is an old-style class; can't use Super()
        ConfigParser.__init__(self, allow_no_value=True)
        if filename:
            self.read(filename)

    def create_ini(self):
        """ construct the contents of the INI file (as a string)"""
        # ConfigParser DOES have its own write() method
        # we could re-implement more of it here
        out = []
        for s in self.sections():
            out.append("[{}]".format(s))
            for (n, v) in self.items(s):
                # This if/else is different from ConfigParser.write()
                if v:
                    out.append("{}={}".format(n, v))
                else:
                    out.append(n)
        return '\n'.join(out)

    def set_host_in_section(self, section, hostname, params):
        """ set a node in a specified section.
        Because ansible variables are space-separated name=value pairs,
        which differs from the ConfigParser, this method provides a
        convenience function that better suits Ansible inventories.

        Args:
            section: the name of the [section] to hold the value
            hostname: the hostname to go in this section
            params: a set of space-separated name=value pairs (a list of
            tuples)
        Returns: nothing
        """
        if not params:
            host_and_first_key = hostname
            remaining_kvps = None
        else:
            # ConfigParser splits on '='. Fake up a left-hand-side
            # with the hostname and the first bit of the Ansible params.
            host_and_first_key = '{} {}'.format(hostname, params[0][0])

            # Fake up the right-hand-side with he remaining params
            remaining_kvps = params[0][1]
            for kvp in params[1:]:
                remaining_kvps = remaining_kvps + ' ' + kvp[0] + '=' + kvp[1]

        self.set(section, host_and_first_key, remaining_kvps)


def parse_args():
    parser = argparse.ArgumentParser(
        description='Test if we need to upscale')
    parser.add_argument(
        '--debug', help='show debug', action='store_true')
    args = parser.parse_args()
    return args


def read_hosts_from_inventory(inventory_file):
    """
    Ansible inventory isn't exactly the same as an INI file. You could use a
    ConfigParser, but it doesn't quite give you the right output. However, you
    can use the Ansible inventory manager.
    http://docs.ansible.com/ansible/latest/dev_guide/developing_api.html
    https://github.com/ansible/ansible/blob/devel/lib/ansible/inventory

    Update: Ansible's Inventory Manager is not useful for WRITING, but the
    ConfigParser can be made to provide the right output

    Args:
        inventory_file: the filename containing the inventory.

    Returns:
        a dict representing the hosts from the inventory file.
        The following keys should be present:
        ['all', 'dns', 'loadbalancers', 'masters', 'ungrouped', 'etcd',
         'OSEv3', 'nodes']
    """
    ivm = InventoryManager(loader=DataLoader(), sources=[inventory_file])
    return ivm.get_groups_dict()


def read_hosts_from_config_yaml(vars_config_file):
    """
    Read from the ansible vars file group_vars/all.yml

    Return a list of tuples, each being (hostname, ip_address)

    """
    with open(vars_config_file, 'r') as vars_fh:
        vars_config = yaml.load(vars_fh)

    output = []
    for k, v in vars_config.items():
        if k in ['haproxy_details', 'master_details', 'worker_details']:
            for ip, host in v.items():
                output.append((host, ip))
    return output


def find_missing_hosts(all_inventory_hosts, new_hosts_list):
    """
    Look for any hostnames that are only in one of the two
    config files

    Args:
        all_inventory_hosts: a list of hostnames, originating
            from the inventory file (
        new_hosts_list: a list of tuples of all the hosts that should be
            in the enlarged cluster. Each is (hostname, ip_address)
    """

    # Does every host in all.yml exist in the inventory?
    discovered_hosts = []
    added = []

    for hostname, ip_addr in new_hosts_list:
        discovered_hosts.append(hostname)
        if hostname not in all_inventory_hosts:
            added.append((hostname, ip_addr))

    return added


def write_scale_up_inventory(old_inventory_file, upscaled_inventory_file,
                             new_hosts, debug=False):
    """
    Scripted implementation of the instructions at
    https://docs.openshift.com/container-platform/3.5/install_config/
        adding_hosts_to_existing_cluster.html#adding-nodes-advanced

    """
    inventory = AnsibleInventory(filename=old_inventory_file)

    for host, ip_arg in new_hosts:
        # the new host is either "master-*.openstacklocal" or
        # worker-*.openstacklocal"

        host_type = ''
        host_num = -1
        if debug:
            print("DEBG: {}".format(host))
        mtch = re.match('(worker|master)-(\d+).openstacklocal', host)
        if mtch:
            host_type = mtch.group(1)
            host_num = int(mtch.group(2))
        assert mtch, "Hostname '{}' did not match pattern".format(host)
        if host_type == 'master':
            raise UpscalingMasterNodeException
            # if is_master:
            #    add_"new_masters" to [OSEv3:children]
            #    add new group [new_masters]
            #    add new group [new_nodes]
            #    add the hostnames to both groups
        elif host_type == 'worker':
            inventory.set('OSEv3:children', 'new_nodes', None)
            if 'new_nodes' not in inventory.sections():
                inventory.add_section('new_nodes')

            # Only the first 3 workers (0, 1, 2) have "router: true"
            # N.B. The equivalent compare in the Jinja code is 1-based.
            if host_num < 3:
                node_labels = "\"{'router':'true','purpose':'tenant'}\""
            else:
                node_labels = "\"{'purpose':'tenant'}\""

            inventory.set_host_in_section(
                'new_nodes', host,
                [('openshift_ip', ip_arg),
                 ('openshift_node_labels', node_labels)])

    with open(upscaled_inventory_file, 'w') as out_fh:
        out_fh.write(inventory.create_ini())
        if debug:
            print(inventory.create_ini())


def main():
    """ - """
    args = parse_args()

    vars_config_file = 'group_vars/all.yml'
    inventory_file = 'openshift-ansible-hosts'

    upscale_inventory_file = 'openshift-ansible-hosts-upscale'

    assert os.path.exists(inventory_file)
    assert os.path.exists(vars_config_file)

    new_hosts_list = read_hosts_from_config_yaml(vars_config_file)
    if args.debug:
        print('DBUG: %r' % new_hosts_list)

    all_inventory_hosts = read_hosts_from_inventory(inventory_file)['all']
    if args.debug:
        print('DBUG: %r' % all_inventory_hosts)

    added_hosts = find_missing_hosts(all_inventory_hosts, new_hosts_list)

    for host, ipaddr in added_hosts:
        print("Adding: %s %s" % (host, ipaddr))

    if len(added_hosts) > 0:
        write_scale_up_inventory(inventory_file, upscale_inventory_file,
                                 added_hosts, args.debug)


#
#
#    Unit tests follow
#
#


def test_read_hosts_from_config_yaml():
    """ - """
    expected = [
        ('haproxy-0.openstacklocal', '10.2.1.8'),
        ('haproxy-1.openstacklocal', '10.2.1.6'),
        ('worker-0.openstacklocal', '10.2.1.11'),
        ('worker-1.openstacklocal', '10.2.1.9'),
        ('worker-2.openstacklocal', '10.2.1.13'),
        ('master-0.openstacklocal', '10.2.1.10'),
        ('master-2.openstacklocal', '10.2.1.12'),
        ('master-1.openstacklocal', '10.2.1.7'),
    ]
    actual = read_hosts_from_config_yaml('group_vars/all.yml')
    assert expected == actual


def test_read_hosts_from_inventory():
    """ read_hosts_from_inventory returns everything in the inventory
    file, each section being a dict key.."""
    should_contain = {
        'masters': [
            'master-0.openstacklocal',
            'master-2.openstacklocal',
            'master-1.openstacklocal',
        ],
        'etcd': [
            'master-0.openstacklocal',
            'master-2.openstacklocal',
            'master-1.openstacklocal',
        ],
        'loadbalancers': [
            'haproxy-0.openstacklocal',
            'haproxy-1.openstacklocal',
        ],
        'dns': [
            'haproxy-0.openstacklocal',
            'haproxy-1.openstacklocal',
        ],
        'nodes': [
            'master-0.openstacklocal',
            'master-2.openstacklocal',
            'master-1.openstacklocal',
            'worker-0.openstacklocal',
            'worker-1.openstacklocal',
        ]
    }

    actual = read_hosts_from_inventory('openshift-ansible-hosts')

    for k, v in should_contain.items():
        assert actual[k] == v
    assert actual.keys() == ['all', 'dns', 'loadbalancers', 'masters',
                             'ungrouped', 'etcd', 'OSEv3', 'nodes']


if __name__ == '__main__':
    main()
