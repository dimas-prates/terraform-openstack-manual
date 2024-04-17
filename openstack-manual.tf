terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = ">= 1.40.0"
    }
  }
}

#variables defined in the file "openstack_variables.tfvars"
variable "auth_url" {}
variable "application_credential_id" {}
variable "application_credential_secret" {}
variable "region" {}
variable "image_id" {}
variable "flavor_name" {}
variable "router_external_network_id" {}

provider "openstack" {
  alias                         = "rc"
  auth_url                      = var.auth_url
  application_credential_id     = var.application_credential_id
  application_credential_secret = var.application_credential_secret
  region                        = var.region
}

# Create a new SSH key pair
resource "openstack_compute_keypair_v2" "openstack-key" {
  provider   = openstack.rc
  name       = "openstack-key"
  public_key = file("./openstack.key.pub")
}

# Create the first network
resource "openstack_networking_network_v2" "openstack-internal-network" {
  provider       = openstack.rc
  name           = "openstack-internal-network"
  admin_state_up = true
}

# Create subnets for the first network
resource "openstack_networking_subnet_v2" "openstack-internal-subnet" {
  provider        = openstack.rc
  network_id      = openstack_networking_network_v2.openstack-internal-network.id
  cidr            = "10.66.66.0/24"
  ip_version      = 4
  dns_nameservers = ["8.8.8.8"]
  allocation_pool {
    start = "10.66.66.2"
    end   = "10.66.66.254"
  }
}

# Create a second network
resource "openstack_networking_network_v2" "openstack-external-network" {
  provider       = openstack.rc
  name           = "openstack-external-network"
  admin_state_up = true
}

# Create subnets for the second network
resource "openstack_networking_subnet_v2" "openstack-external-subnet" {
  provider        = openstack.rc
  network_id      = openstack_networking_network_v2.openstack-external-network.id
  cidr            = "10.166.166.0/24" # Example CIDR for the second subnet
  ip_version      = 4
  dns_nameservers = ["8.8.8.8"]
  allocation_pool {
    start = "10.166.166.2"
    end   = "10.166.166.254"
  }
}

# Create a new security group allowing SSH
resource "openstack_networking_secgroup_v2" "openstack-security-group" {
  provider    = openstack.rc
  name        = "openstack-security-group"
  description = "openstack rules"
}

# Define security group rules for SSH access
resource "openstack_networking_secgroup_rule_v2" "ssh-security-rule" {
  provider          = openstack.rc
  security_group_id = openstack_networking_secgroup_v2.openstack-security-group.id
  direction         = "ingress"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  ethertype         = "IPv4" # Specify the ethertype as "IPv4"
}

# Create a router
resource "openstack_networking_router_v2" "openstack-router" {
  provider         = openstack.rc
  name             = "openstack-router"
  external_gateway = var.router_external_network_id
}

# Attach subnets to the router
resource "openstack_networking_router_interface_v2" "internal-subnet-interface" {
  provider  = openstack.rc
  router_id = openstack_networking_router_v2.openstack-router.id
  subnet_id = openstack_networking_subnet_v2.openstack-internal-subnet.id
}

resource "openstack_networking_router_interface_v2" "external-subnet-interface" {
  provider  = openstack.rc
  router_id = openstack_networking_router_v2.openstack-router.id
  subnet_id = openstack_networking_subnet_v2.openstack-external-subnet.id
}

# Launch instances
resource "openstack_compute_instance_v2" "openstack-controller-instances" {
  provider        = openstack.rc
  count           = 2
  name            = "controller-${count.index + 1}"
  flavor_name     = var.flavor_name
  key_pair        = openstack_compute_keypair_v2.openstack-key.name
  security_groups = [openstack_networking_secgroup_v2.openstack-security-group.name, "default"]
  user_data       = file("./cloud-config.yaml")
  network {
    name = openstack_networking_network_v2.openstack-internal-network.name
  }
  network {
    name = openstack_networking_network_v2.openstack-external-network.name
  }
  block_device {
    uuid             = var.image_id
    source_type      = "image"
    destination_type = "volume"
    boot_index       = 0
    volume_size      = 20 # Adjust size as needed
  }
}

# Create additional compute instances
resource "openstack_compute_instance_v2" "openstack-compute-instances" {
  provider        = openstack.rc
  count           = 2
  name            = "compute-${count.index + 1}"
  flavor_name     = var.flavor_name
  key_pair        = openstack_compute_keypair_v2.openstack-key.name
  security_groups = [openstack_networking_secgroup_v2.openstack-security-group.name, "default"]
  user_data       = file("./cloud-config.yaml")
  network {
    name = openstack_networking_network_v2.openstack-internal-network.name
  }
  network {
    name = openstack_networking_network_v2.openstack-external-network.name
  }
  block_device {
    uuid             = var.image_id
    source_type      = "image"
    destination_type = "volume"
    boot_index       = 0
    volume_size      = 20 # Adjust size as needed
  }
}

# Create deploy instance
resource "openstack_compute_instance_v2" "deploy-instance" {
  provider        = openstack.rc
  count           = 1
  name            = "deploy-1"
  flavor_name     = "bc1-basic-2-4"
  key_pair        = openstack_compute_keypair_v2.openstack-key.name
  security_groups = [openstack_networking_secgroup_v2.openstack-security-group.name, "default"]
  user_data       = file("./cloud-config.yaml")
  network {
    name = openstack_networking_network_v2.openstack-internal-network.name
  }
  network {
    name = openstack_networking_network_v2.openstack-external-network.name
  }
  block_device {
    uuid             = var.image_id
    source_type      = "image"
    destination_type = "volume"
    boot_index       = 0
    volume_size      = 20 # Adjust size as needed
  }
}