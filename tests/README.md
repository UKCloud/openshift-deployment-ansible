To use these tests run the following:

```
ansible-playbook ./openshift-deployment-ansible/tests/all.yml --extra-vars "hostIP=<IP_address_of_Bastion_host>" --extra-vars OPENSHIFT_USERNAME=\"\$OPENSHIFT_USERNAME\" --extra-vars OPENSHIFT_PASSWORD=\"\$OPENSHIFT_PASSWORD\" --extra-vars server=\"<target_server>\"
```

