To use these tests run the following:

```
ansible-playbook ./openshift-deployment-ansible/tests/all.yml --extra-vars "hostIP=<IP_address_of_Bastion_host>" --extra-vars "openshiftUsername=<username>" --extra-vars "openshiftPassword=<password>" --extra-vars server=\"<target_server>\"
```

