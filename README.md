# k8s-calico-os

* Create VMs using terraform
```
terraform apply
```
* Add machines using commands in terraform output
* Run ansible to install jump host
```
ansible-playbook -i inventory jumphost.yaml
```
* Run Juju to deploy K8s
```
juju deploy ./k8s-calico.yaml
```

Useful commands
(On master)
```
calicoctl node status
calicoctl get ippool
calicoctl get bgppeer
```
(On jump host)
```
birdc show route
```

Determine best networking option
https://docs.projectcalico.org/networking/determine-best-networking

Configure calicoctl to connect to the Kubernetes API datastore
https://docs.projectcalico.org/getting-started/clis/calicoctl/configure/kdd