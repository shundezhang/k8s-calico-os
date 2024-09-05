terraform {
  required_providers {
    openstack = {
      source = "terraform-provider-openstack/openstack"
      version = "~> 2.1.0"
    }
    juju = {
      source  = "juju/juju"
      version = "~> 0.13.0"
    }
  }
  required_version = ">= 0.13"
}
