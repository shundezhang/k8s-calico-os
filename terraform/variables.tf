variable "image" {
  type        = string
  default = "auto-sync/ubuntu-bionic-18.04-amd64-server-20200807-disk1.img"
}

variable "key_name" {
  type        = string
  default = "lpkey"
}

variable "network_main" {
  type = string
  default = "shunde-zhang_admin_net"
}

variable "calico_sec_groups" {
  type = list
  default = []
}

variable "master_flavor" {
  type        = string
  default = "m1.medium"
}

variable "master_count" {
  type = number
  default = 3
}

variable "network_calico" {
  type = string
  default = "calico_network"
}

variable "network_calico_cidr" {
  type = string
  default = "192.168.0.0/16"
}

variable "worker_count" {
  type = number
  default = 1
}

variable "worker_flavor" {
  type        = string
  default = "m1.small"
}

variable "jump_host_flavor" {
  type        = string
  default = "m1.small"
}
