provider "openstack" {}

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
  k8s_hosts_map = tomap({"host_name"=openstack_compute_instance_v2.worker[*].name, "host_ip"=openstack_compute_instance_v2.worker[*].network[0].fixed_ip_v4})
}
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl",
    {
      jump_host = openstack_compute_instance_v2.jump_host.network[0].fixed_ip_v4
      k8s_hosts = jsonencode(k8s_hosts_map)
    }
  )
  filename = "../ansible/inventory"
}

