provider "openstack" {}

provider "juju" {}

resource "openstack_networking_network_v2" "network_calico" {
  name           = var.network_calico
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "subnet_calico" {
  name       = "${var.network_calico}_subnet"
  network_id = openstack_networking_network_v2.network_calico.id
  cidr       = var.network_calico_cidr
  allocation_pool {
    start = var.network_calico_start_ip
    end   = var.network_calico_end_ip
  }
  ip_version = 4
}

resource "openstack_networking_secgroup_v2" "network_calico_secgroup" {
  name        = "${var.network_calico}_secgroup"
  description = "a security group for calico network"
}

resource "openstack_networking_secgroup_rule_v2" "network_calico_secgroup_rule_tcp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 1
  port_range_max    = 65535
  remote_group_id = openstack_networking_secgroup_v2.network_calico_secgroup.id
  security_group_id = openstack_networking_secgroup_v2.network_calico_secgroup.id
}

resource "openstack_networking_secgroup_rule_v2" "network_calico_secgroup_rule_udp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 1
  port_range_max    = 65535
  remote_group_id = openstack_networking_secgroup_v2.network_calico_secgroup.id
  security_group_id = openstack_networking_secgroup_v2.network_calico_secgroup.id
}

resource "openstack_networking_port_v2" "master_port" {
  count              = var.master_count
  name               = "master_port_${count.index}"
  network_id         = openstack_networking_network_v2.network_calico.id
  admin_state_up     = "true"
  security_group_ids = [openstack_networking_secgroup_v2.network_calico_secgroup.id]
  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.subnet_calico.id
  }
}

resource "openstack_compute_instance_v2" "master" {
  count           = var.master_count
  name            = "master_${count.index}"
  image_name      = var.image
  flavor_name     = var.master_flavor
  key_pair        = var.key_name
  security_groups = var.calico_sec_groups

  network {
    name = var.network_main
  }

  network {
    port = openstack_networking_port_v2.master_port[count.index].id
  }

}

resource "openstack_networking_port_v2" "worker_port" {
  count              = var.worker_count
  name               = "worker_port_${count.index}"
  network_id         = openstack_networking_network_v2.network_calico.id
  admin_state_up     = "true"
  security_group_ids = [openstack_networking_secgroup_v2.network_calico_secgroup.id]
  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.subnet_calico.id
  }
}

resource "openstack_compute_instance_v2" "worker" {
  count           = var.worker_count
  name            = "worker_${count.index}"
  image_name      = var.image
  flavor_name     = var.worker_flavor
  key_pair        = var.key_name
  security_groups = var.calico_sec_groups

  network {
    name = var.network_main
  }

  network {
    port = openstack_networking_port_v2.worker_port[count.index].id
  }

}

resource "openstack_networking_port_v2" "jump_host_port" {
  name               = "jump_host_port"
  network_id         = openstack_networking_network_v2.network_calico.id
  admin_state_up     = "true"
  security_group_ids = [openstack_networking_secgroup_v2.network_calico_secgroup.id]
  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.subnet_calico.id
  }
}

resource "openstack_compute_instance_v2" "jump_host" {
  name            = "jump_host"
  image_name      = var.image
  flavor_name     = var.jump_host_flavor
  key_pair        = var.key_name
  security_groups = var.calico_sec_groups

  network {
    name = var.network_main
  }

  network {
    port = openstack_networking_port_v2.jump_host_port.id
  }

}

locals {
  k8s_hosts_map = merge(
     zipmap(openstack_compute_instance_v2.master[*].name, openstack_compute_instance_v2.master[*].network[0].fixed_ip_v4),
     zipmap(openstack_compute_instance_v2.worker[*].name, openstack_compute_instance_v2.worker[*].network[0].fixed_ip_v4)
  )
}

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl",
    {
      jump_host = openstack_compute_instance_v2.jump_host.network[0].fixed_ip_v4
      k8s_hosts = jsonencode(local.k8s_hosts_map)
    }
  )
  filename = "../ansible/inventory"
  file_permission = "0644"
}

resource "juju_model" "k8s_calico" {
  name = "k8s-calico"
  cloud {
    name = var.juju_cloud_name
  }
  config = {
    network = "${var.network_main},${var.network_calico}"
  }
}

resource "juju_application" "calico" {
  name  = "calico"
  model = juju_model.k8s_calico.name

  charm {
    name    = "calico"
    channel = "1.28/stable"
  }

  config = {
    cidr = "192.168.128.0/18"
    global-as-number = 64552
    global-bgp-peers = "[{address: 192.168.0.193, as-number: 64512}]"
    ipip = "Never"
    nat-outgoing = false
    node-to-node-mesh = true
  }
  units = 0
  lifecycle {
      ignore_changes = [ placement, ]
  }
}

resource "juju_application" "containerd" {
  name  = "containerd"
  model = juju_model.k8s_calico.name

  charm {
    name    = "containerd"
    channel = "1.28/stable"
  }
  units = 0
  lifecycle {
      ignore_changes = [ placement, ]
  }

}

resource "juju_application" "easyrsa" {
  name  = "easyrsa"
  model = juju_model.k8s_calico.name

  charm {
    name    = "easyrsa"
    channel = "1.28/stable"
  }

  placement = local.k8s_juju_ids[0]
}

resource "juju_application" "etcd" {
  name  = "etcd"
  model = juju_model.k8s_calico.name

  charm {
    name    = "etcd"
    channel = "1.28/stable"
  }

  config = {
    channel = "3.4/stable"
  }
  placement = local.k8s_juju_ids[0]
}

resource "juju_application" "kubernetes_worker" {
  name  = "kubernetes_worker"
  model = juju_model.k8s_calico.name

  charm {
    name    = "kubernetes-worker"
    channel = "1.28/stable"
  }

  config = {
    kubelet-extra-config = "{}"
  }

  placement = join(",", slice(local.k8s_juju_ids, 1, length(local.k8s_juju_ids)))

  lifecycle {
        ignore_changes = [ placement, ]
  }
}

resource "juju_application" "kubernetes_control_plane" {
  name  = "kubernetes_control_plane"
  model = juju_model.k8s_calico.name

  charm {
    name    = "kubernetes-control-plane"
    channel = "1.28/stable"
  }

  config = {
    allow-privileged = "true"
    api-extra-args = ""
    audit-webhook-config = ""
    authorization-mode = "RBAC,Node"
    service-cidr = "192.168.192.0/18"
    audit-policy = <<EOT
        apiVersion: audit.k8s.io/v1beta1
        kind: Policy
        rules:
        # Don't log read-only requests from the apiserver
        - level: None
          users: ["system:apiserver"]
          verbs: ["get", "list", "watch"]
        # Don't log kube-proxy watches
        - level: None
          users: ["system:kube-proxy"]
          verbs: ["watch"]
          resources:
          - resources: ["endpoints", "services"]
        # Don't log nodes getting their own status
        - level: None
          userGroups: ["system:nodes"]
          verbs: ["get"]
          resources:
          - resources: ["nodes"]
        # Don't log kube-controller-manager and kube-scheduler getting endpoints
        - level: None
          users: ["system:unsecured"]
          namespaces: ["kube-system"]
          verbs: ["get"]
          resources:
          - resources: ["endpoints"]
        # Log everything else at the Request level.
        - level: Request
          omitStages:
          - RequestReceived
    EOT
  }

  placement = local.k8s_juju_ids[0]
}

resource "juju_machine" "k8s_machine" {
  count = var.worker_count+1
  model = juju_model.k8s_calico.name
}

locals {
    k8s_juju_ids = [for machine in juju_machine.k8s_machine: split(":", machine.id)[1]]
}

resource "juju_integration" "etcd-easyrsa" {
  model = juju_model.k8s_calico.name

  application {
    name = juju_application.etcd.name
    endpoint = "certificates"
  }

  application {
    name = juju_application.easyrsa.name
    endpoint = "client"
  }
}

resource "juju_integration" "kubernetes-control-plane-worker" {
  model = juju_model.k8s_calico.name

  application {
    name = juju_application.kubernetes_control_plane.name
    endpoint = "kube-control"
  }

  application {
    name = juju_application.kubernetes_worker.name
    endpoint = "kube-control"
  }
}