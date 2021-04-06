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

