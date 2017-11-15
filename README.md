
To execute the playbooks and set up your Openshift environment, run the following:

```
./deploy-openshift.sh
``` 

The environment definition file (./group_vars/all.yml) is written by the openshift-heat code. The filename is a default location in
Ansible, so there is no need to specify it when running playbooks; it will be loaded automatically.


The `deploy-openshift.sh` script builds the inventory file from roles/initialisation/templates/ansible-hosts-multimaster.j2, then runs the top-level
playbook for the site (site.yml)

The playbook is broken into sub-playbooks, and tasks are organised into roles, making it easier to deploy different confirations or partial deployments.
