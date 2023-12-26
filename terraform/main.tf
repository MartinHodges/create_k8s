terraform {
required_version = ">= 1.5.5"
  required_providers {
    restapi = {
      source = "Mastercard/restapi"
    }
  }
}

module "vpc" {
  source = "./modules/vpc"
  vpc_name = "${var.project_prefix}-vpc"
}

output "vpc" {
  description = "vpc"
  value = module.vpc.vpc_desc
}

module "gw" {
  source = "./modules/public_vps"
  vps_name = "${var.project_prefix}-gw"
  vps_flavour = "std-1vcpu"
  vpc_id = module.vpc.vpc_desc.id
  ssh_key = var.ssh_key
}

output "gw" {
  description = "gw"
  value = module.gw.v4_ips
}

module "openvpn" {
  source = "./modules/public_vps"
  vps_name = "${var.project_prefix}-openvpn"
  vps_flavour = "std-1vcpu"
  vpc_id = module.vpc.vpc_desc.id
  ssh_key = var.ssh_key
  port_blocking = false
}

output "openvpn" {
  description = "openvpn"
  value = module.k8s_master.v4_ips
}

module "k8s_master" {
  source = "./modules/private_vps"
  vps_name = "${var.project_prefix}-k8s-master"
  vps_flavour = "std-2vcpu"
  vpc_id = module.vpc.vpc_desc.id
  ssh_key = var.ssh_key
}

output "k8s_master" {
  description = "k8s_master"
  value = module.k8s_master.v4_ips
}

module "k8s_node_1" {
  source = "./modules/private_vps"
  vps_name = "${var.project_prefix}-k8s-node-1"
  vps_flavour = "std-1vcpu"
  vpc_id = module.vpc.vpc_desc.id
  ssh_key = var.ssh_key
}

output "k8s_node_1" {
  description = "k8s_node_1"
  value = module.k8s_node_1.v4_ips
}

module "k8s_node_2" {
  source = "./modules/private_vps"
  vps_name = "${var.project_prefix}-k8s-node-2"
  vps_flavour = "std-1vcpu"
  vpc_id = module.vpc.vpc_desc.id
  ssh_key = var.ssh_key
}

output "k8s_node_2" {
  description = "k8s_node_2"
  value = module.k8s_node_2.v4_ips
}

resource "local_file" "inventory" {
  filename = "../ansible/inventory"
  content = templatefile("ansible_inventory.tftpl", {
    openvpn_ip = module.openvpn.v4_ips.public
    gw_ip = module.gw.v4_ips.public
    master_ip = module.k8s_master.v4_ips.private
    node_ips = [
      module.k8s_node_1.v4_ips.private,
      module.k8s_node_2.v4_ips.private
    ]
  })
}

