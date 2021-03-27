output "master_ips" {
  description = "master ips"
  value = formatlist("juju add-machine ssh:ubuntu@%s", openstack_compute_instance_v2.master[*].network[0].fixed_ip_v4)
}

output "worker_ips" {
  description = "worker ips"
  value = formatlist("juju add-machine ssh:ubuntu@%s", openstack_compute_instance_v2.worker[*].network[0].fixed_ip_v4)
}

output "jump_host_ips" {
  description = "jump host ip"
  value = openstack_compute_instance_v2.jump_host.network[0].fixed_ip_v4
}