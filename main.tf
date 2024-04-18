terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = ">= 1.40.0"
    }
  }
}

variable "auth_url" {}
variable "region" {}
variable "application_credential_id" {}
variable "application_credential_secret" {}
variable "image_id" {}
variable "router_external_network_id" {}
variable "flavor_name_compute" {}
variable "flavor_name_controller" {}
variable "flavor_name_storage" {}
variable "flavor_name_firewall" {}
variable "external_remote_ip" {}

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

# Create an object storage container with private access
resource "openstack_objectstorage_container_v1" "openstack-object-storage-container" {
  provider = openstack.rc
  name     = "openstack-object-storage"
  metadata = {
    access_control = "private"
  }
  force_destroy = true
}

# Create a new security group allowing access
resource "openstack_networking_secgroup_v2" "openstack-security-group-access" {
  provider    = openstack.rc
  name        = "openstack-security-group-access"
  description = "openstack rules"
}

# Create a new security group allowing VPN
resource "openstack_networking_secgroup_v2" "openstack-security-group-vpn" {
  provider    = openstack.rc
  name        = "openstack-security-group-vpn"
  description = "openstack rules"
}

# Create security group rule for SSH
resource "openstack_networking_secgroup_rule_v2" "ssh-security-rule" {
  provider          = openstack.rc
  security_group_id = openstack_networking_secgroup_v2.openstack-security-group-access.id
  direction         = "ingress"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22

  remote_ip_prefix  = var.external_remote_ip
  ethertype         = "IPv4"  # Specify the ethertype as "IPv4"
}

# Create security group rule for SSH
resource "openstack_networking_secgroup_rule_v2" "vpn-security-rule" {
  provider          = openstack.rc
  security_group_id = openstack_networking_secgroup_v2.openstack-security-group-vpn.id
  direction         = "ingress"
  protocol          = "udp"
  port_range_min    = 1194
  port_range_max    = 1194

  remote_ip_prefix  = var.external_remote_ip
  ethertype         = "IPv4"  # Specify the ethertype as "IPv4"
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

# Create controllers instances
resource "openstack_compute_instance_v2" "openstack-controller-instances" {
  provider        = openstack.rc
  count           = 3
  name            = "controller-${count.index + 1}"
  flavor_name     = var.flavor_name_controller
  key_pair        = openstack_compute_keypair_v2.openstack-key.name
  security_groups = [openstack_networking_secgroup_v2.openstack-security-group-access.name, "default"]
  user_data       = file("./cloud-config.yaml")
  network {
    name = openstack_networking_network_v2.openstack-internal-network.name
  }
  network {
    name = openstack_networking_network_v2.openstack-external-network.name
  }
  block_device {
    uuid                  = var.image_id
    source_type           = "image"
    destination_type      = "volume"
    boot_index            = 0
    volume_size           = 10   # Adjust size as needed
    delete_on_termination = true # Set this flag to delete the volume on instance termination
  }
}

# Create compute instances
resource "openstack_compute_instance_v2" "openstack-compute-instances" {
  provider        = openstack.rc
  count           = 2
  name            = "compute-${count.index + 1}"
  flavor_name     = var.flavor_name_compute
  key_pair        = openstack_compute_keypair_v2.openstack-key.name
  security_groups = [openstack_networking_secgroup_v2.openstack-security-group-access.name, "default"]
  user_data       = file("./cloud-config.yaml")
  network {
    name = openstack_networking_network_v2.openstack-internal-network.name
  }
  network {
    name = openstack_networking_network_v2.openstack-external-network.name
  }
  block_device {
    uuid                  = var.image_id
    source_type           = "image"
    destination_type      = "volume"
    boot_index            = 0
    volume_size           = 10   # Adjust size as needed
    delete_on_termination = true # Set this flag to delete the volume on instance termination
  }
}

# Create Storage instances
resource "openstack_compute_instance_v2" "openstack-storage-instances" {
  provider        = openstack.rc
  count           = 2
  name            = "storage-${count.index + 1}"
  flavor_name     = var.flavor_name_storage
  key_pair        = openstack_compute_keypair_v2.openstack-key.name
  security_groups = [openstack_networking_secgroup_v2.openstack-security-group-access.name, "default"]
  user_data       = file("./cloud-config.yaml")
  network {
    name = openstack_networking_network_v2.openstack-internal-network.name
  }
  network {
    name = openstack_networking_network_v2.openstack-external-network.name
  }
  block_device {
    uuid                  = var.image_id
    source_type           = "image"
    destination_type      = "volume"
    boot_index            = 0
    volume_size           = 350  # Adjust size as needed
    delete_on_termination = true # Set this flag to delete the volume on instance termination
  }
}

# Create VPN instance
resource "openstack_compute_instance_v2" "vpn-instance" {
  provider        = openstack.rc
  count           = 1
  name            = "vpn-1"
  flavor_name     = var.flavor_name_firewall
  key_pair        = openstack_compute_keypair_v2.openstack-key.name
  security_groups = [openstack_networking_secgroup_v2.openstack-security-group-access.name, openstack_networking_secgroup_v2.openstack-security-group-vpn.name, "default"]
  user_data       = file("./cloud-config.yaml")
  network {
    name = openstack_networking_network_v2.openstack-internal-network.name
  }
  network {
    name = openstack_networking_network_v2.openstack-external-network.name
  }
  block_device {
    uuid                  = var.image_id
    source_type           = "image"
    destination_type      = "volume"
    boot_index            = 0
    volume_size           = 10   # Adjust size as needed
    delete_on_termination = true # Set this flag to delete the volume on instance termination
  }
}
