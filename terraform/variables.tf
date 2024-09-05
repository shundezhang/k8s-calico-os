variable "image" {
  type        = string
  default = "auto-sync/ubuntu-focal-20.04-amd64-server-20240821-disk1.img"
}

variable "key_name" {
  type        = string
  default = "lpkey"
}

variable "network_main" {
  type = string
  default = "net_stg-reproducer-shunde-zhang-psd"
}

variable "calico_sec_groups" {
  type = list
  default = []
}

variable "master_flavor" {
  type        = string
  default = "staging-cpu1-ram2-disk20"
}

variable "master_count" {
  type = number
  default = 1
}

variable "network_calico" {
  type = string
  default = "calico_network"
}

variable "network_calico_cidr" {
  type = string
  default = "192.168.0.0/16"
}

variable "network_calico_start_ip" {
  type        = string
  default = "192.168.0.10"
}

variable "network_calico_end_ip" {
  type        = string
  default = "192.168.0.200"
}

variable "worker_count" {
  type = number
  default = 1
}

variable "worker_flavor" {
  type        = string
  default = "staging-cpu1-ram2-disk20"
}

variable "jump_host_flavor" {
  type        = string
  default = "staging-cpu1-ram2-disk20"
}

variable "juju_cloud_name" {
  type        = string
  default = "prodstack"
}
