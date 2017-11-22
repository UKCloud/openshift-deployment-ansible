To use these tests run the following:

The environment variables set by the pipeline need to be overwritten. The pipeline automatically overwrites the target host, therefore we need to unset them so we can deploy the pods within the correct environment. 

```
for var in \$(export | grep KUB | awk '{ print \$2 }' | sed 's/\\=.*//g'); do unset \$var; done; source ./openstack_rc.sh ;
ansible-playbook ./openshift-deployment-ansible/tests/all.yml --extra-vars "hostIP=<IP_address_of_Bastion_host>" --extra-vars OPENSHIFT_USERNAME=\"\$OPENSHIFT_USERNAME\" --extra-vars OPENSHIFT_PASSWORD=\"\$OPENSHIFT_PASSWORD\" --extra-vars server=\"<target_server>\"
```

