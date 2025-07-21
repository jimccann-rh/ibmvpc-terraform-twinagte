# IBM Cloud VPC Terraform Configuration
# Creates a virtual instance with Twingate connector setup on first boot

terraform {
  required_version = ">= 1.0"
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "~> 1.63.0"
    }
  }
}

# Configure IBM Cloud Provider
provider "ibm" {
  # Authentication can be done via:
  # 1. Environment variables: IC_API_KEY
  # 2. IBM Cloud CLI: ibmcloud login
  # 3. Specify directly: ibmcloud_api_key = "your-api-key"
  region = var.region
}

# Variables
variable "region" {
  description = "IBM Cloud region"
  type        = string
  default     = "us-east"
}

variable "zone" {
  description = "Availability zone within the region"
  type        = string
  default     = "us-east-1"
}

variable "resource_group" {
  description = "Resource group name"
  type        = string
  default     = "default"
}

variable "ssh_key_name" {
  description = "Name of the SSH key to use for the instance"
  type        = string
  default     = "twingate-connector-key"
}

variable "instance_name" {
  description = "Name for the virtual server instance"
  type        = string
  default     = "twingate-connector-vsi"
}

variable "instance_profile" {
  description = "Instance profile for the virtual server"
  type        = string
  default     = "bx2-2x8"  # 2 vCPUs, 8 GB RAM
}

variable "enable_floating_ip" {
  description = "Enable floating IP for external access to the VSI"
  type        = bool
  default     = true
}

variable "twingate_access_token" {
  description = "Twingate access token for connector authentication"
  type        = string
  sensitive   = true
}

variable "twingate_refresh_token" {
  description = "Twingate refresh token for connector authentication"
  type        = string
  sensitive   = true
}

variable "twingate_network" {
  description = "Twingate network name"
  type        = string
  default     = "mynetwork"
}

# Data sources
data "ibm_resource_group" "resource_group" {
  name = var.resource_group
}

data "ibm_is_image" "os_image" {
  name = "ibm-centos-stream-9-amd64-11"
}

data "ibm_is_ssh_key" "ssh_key" {
  name = var.ssh_key_name
}

# Create VPC
resource "ibm_is_vpc" "twingate_vpc" {
  name                        = "${var.instance_name}-vpc"
  resource_group              = data.ibm_resource_group.resource_group.id
  address_prefix_management   = "auto"
  default_network_acl_name    = "${var.instance_name}-default-acl"
  default_routing_table_name  = "${var.instance_name}-default-rt"
  default_security_group_name = "${var.instance_name}-default-sg"

  tags = [
    "twingate",
    "connector",
    "terraform"
  ]
}

# Create subnet
resource "ibm_is_subnet" "twingate_subnet" {
  name                     = "${var.instance_name}-subnet"
  vpc                      = ibm_is_vpc.twingate_vpc.id
  zone                     = var.zone
  resource_group           = data.ibm_resource_group.resource_group.id
  total_ipv4_address_count = 64

  tags = [
    "twingate",
    "connector",
    "terraform"
  ]
}

# Create security group
resource "ibm_is_security_group" "twingate_sg" {
  name           = "${var.instance_name}-sg"
  vpc            = ibm_is_vpc.twingate_vpc.id
  resource_group = data.ibm_resource_group.resource_group.id

  tags = [
    "twingate",
    "connector",
    "terraform"
  ]
}

# Security group rule for SSH
resource "ibm_is_security_group_rule" "ssh_inbound" {
  group     = ibm_is_security_group.twingate_sg.id
  direction = "inbound"
  remote    = "0.0.0.0/0"

  tcp {
    port_min = 22
    port_max = 22
  }
}

# Security group rule for all outbound traffic
resource "ibm_is_security_group_rule" "all_outbound" {
  group     = ibm_is_security_group.twingate_sg.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
}

# Create public gateway for internet access
resource "ibm_is_public_gateway" "twingate_gateway" {
  name           = "${var.instance_name}-gateway"
  vpc            = ibm_is_vpc.twingate_vpc.id
  zone           = var.zone
  resource_group = data.ibm_resource_group.resource_group.id

  tags = [
    "twingate",
    "connector",
    "terraform"
  ]
}

# Attach public gateway to subnet
resource "ibm_is_subnet_public_gateway_attachment" "twingate_gateway_attachment" {
  subnet         = ibm_is_subnet.twingate_subnet.id
  public_gateway = ibm_is_public_gateway.twingate_gateway.id
}

# Cloud-init user data for Twingate connector setup
locals {
  user_data = <<-EOF
#cloud-config

# Cloud-init to run Twingate connector setup on first boot
# Based on the tgconnect file - configured for CentOS Stream 9

package_update: true

packages:
  - curl

write_files:
  - path: /var/log/twingate-install.log
    permissions: '0644'
    owner: root:root
    content: |
      Twingate connector installation log

runcmd:
  - echo "$(date): Starting Twingate connector installation on CentOS Stream 9" >> /var/log/twingate-install.log
  # Ensure system is up to date
  - dnf update -y >> /var/log/twingate-install.log 2>&1
  # Install required packages
  - dnf install -y curl wget >> /var/log/twingate-install.log 2>&1
  # Run the exact command from tgconnect file using Terraform variables
  - curl "https://binaries.twingate.com/connector/setup.sh" | sudo TWINGATE_ACCESS_TOKEN="${var.twingate_access_token}" TWINGATE_REFRESH_TOKEN="${var.twingate_refresh_token}" TWINGATE_NETWORK="${var.twingate_network}" TWINGATE_LABEL_DEPLOYED_BY="terraform-ibm-centos" bash >> /var/log/twingate-install.log 2>&1
  - echo "$(date): Twingate connector installation completed" >> /var/log/twingate-install.log
  - systemctl enable twingate-connector >> /var/log/twingate-install.log 2>&1 || echo "Service enable failed" >> /var/log/twingate-install.log

final_message: "Twingate connector has been installed via Terraform cloud-init on CentOS Stream 9"
EOF
}

# Create virtual server instance
resource "ibm_is_instance" "twingate_vsi" {
  name           = var.instance_name
  vpc            = ibm_is_vpc.twingate_vpc.id
  zone           = var.zone
  profile        = var.instance_profile
  image          = data.ibm_is_image.os_image.id
  resource_group = data.ibm_resource_group.resource_group.id
  user_data      = base64encode(local.user_data)

  primary_network_interface {
    subnet          = ibm_is_subnet.twingate_subnet.id
    security_groups = [ibm_is_security_group.twingate_sg.id]
  }

  keys = [data.ibm_is_ssh_key.ssh_key.id]

  tags = [
    "twingate",
    "connector",
    "terraform"
  ]

  # Wait for subnet to have public gateway attached
  depends_on = [ibm_is_subnet_public_gateway_attachment.twingate_gateway_attachment]
}

# Create floating IP for external access (enabled by default)
resource "ibm_is_floating_ip" "twingate_fip" {
  count          = var.enable_floating_ip ? 1 : 0
  name           = "${var.instance_name}-fip"
  target         = ibm_is_instance.twingate_vsi.primary_network_interface[0].id
  resource_group = data.ibm_resource_group.resource_group.id

  tags = [
    "twingate",
    "connector",
    "terraform"
  ]
}

# Outputs
output "instance_id" {
  description = "ID of the virtual server instance"
  value       = ibm_is_instance.twingate_vsi.id
}

output "instance_private_ip" {
  description = "Private IP address of the instance"
  value       = ibm_is_instance.twingate_vsi.primary_network_interface[0].primary_ipv4_address
}

output "instance_public_ip" {
  description = "Public IP address of the instance (if floating IP is enabled)"
  value       = var.enable_floating_ip ? ibm_is_floating_ip.twingate_fip[0].address : "No floating IP assigned"
}

output "ssh_command" {
  description = "SSH command to connect to the instance (if floating IP is enabled)"
  value       = var.enable_floating_ip ? "ssh root@${ibm_is_floating_ip.twingate_fip[0].address}" : "No floating IP - use private IP for SSH access"
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = ibm_is_vpc.twingate_vpc.id
}

output "subnet_id" {
  description = "ID of the subnet"
  value       = ibm_is_subnet.twingate_subnet.id
}

output "twingate_install_log" {
  description = "Command to check Twingate installation log"
  value       = var.enable_floating_ip ? "ssh root@${ibm_is_floating_ip.twingate_fip[0].address} 'tail -f /var/log/twingate-install.log'" : "Use private IP to check logs: ssh root@${ibm_is_instance.twingate_vsi.primary_network_interface[0].primary_ipv4_address} 'tail -f /var/log/twingate-install.log'"
}

output "floating_ip_enabled" {
  description = "Whether floating IP is enabled for the instance"
  value       = var.enable_floating_ip
} 