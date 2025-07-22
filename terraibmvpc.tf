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
  default     = "Default"
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

# Cloud-init configuration for Twingate connector setup on first boot
# Configured for CentOS Stream 9

package_update: true

packages:
  - curl

write_files:
  - path: /tmp/cloud-init-debug.log
    permissions: '0644'
    owner: root:root
    content: |
      Cloud-init write_files section executed at $(date)
      
  - path: /opt/twingate-setup.sh
    permissions: '0755'
    owner: root:root
    content: |
      #!/bin/bash
      
      # Twingate Connector Setup Script with Enhanced Logging
      LOG_FILE="/var/log/twingate-install.log"
      
      # Create log file and set permissions
      touch "$LOG_FILE"
      chmod 644 "$LOG_FILE"
      
      echo "========================================" >> "$LOG_FILE"
      echo "$(date): Starting Twingate connector installation on CentOS Stream 9" >> "$LOG_FILE"
      echo "Cloud-init user-data execution log" >> "$LOG_FILE"
      echo "========================================" >> "$LOG_FILE"
      
      # Set environment variables from Terraform
      export TWINGATE_ACCESS_TOKEN="${var.twingate_access_token}"
      export TWINGATE_REFRESH_TOKEN="${var.twingate_refresh_token}"
      export TWINGATE_NETWORK="${var.twingate_network}"
      export TWINGATE_LABEL_DEPLOYED_BY="terraform-ibm-centos"
      
      echo "$(date): Environment variables set" >> "$LOG_FILE"
      echo "$(date): TWINGATE_NETWORK=$TWINGATE_NETWORK" >> "$LOG_FILE"
      echo "$(date): TWINGATE_LABEL_DEPLOYED_BY=$TWINGATE_LABEL_DEPLOYED_BY" >> "$LOG_FILE"
      
      # Ensure system is up to date
      echo "$(date): Updating system packages..." >> "$LOG_FILE"
      dnf update -y >> "$LOG_FILE" 2>&1
      echo "$(date): System update completed" >> "$LOG_FILE"
      
      # Install required packages
      echo "$(date): Installing required packages..." >> "$LOG_FILE"
      dnf install -y curl wget >> "$LOG_FILE" 2>&1
      echo "$(date): Package installation completed" >> "$LOG_FILE"
      
      # Download and execute Twingate setup script
      echo "$(date): Downloading and executing Twingate connector setup..." >> "$LOG_FILE"
      curl -fsSL "https://binaries.twingate.com/connector/setup.sh" | bash >> "$LOG_FILE" 2>&1
      echo "$(date): Twingate connector installation completed" >> "$LOG_FILE"
      
      # Enable and start the service
      echo "$(date): Enabling Twingate connector service..." >> "$LOG_FILE"
      systemctl enable twingate-connector >> "$LOG_FILE" 2>&1
      systemctl start twingate-connector >> "$LOG_FILE" 2>&1
      echo "$(date): Service operations completed" >> "$LOG_FILE"
      
      # Check service status
      echo "$(date): Checking service status..." >> "$LOG_FILE"
      systemctl status twingate-connector >> "$LOG_FILE" 2>&1
      
      echo "========================================" >> "$LOG_FILE"
      echo "$(date): Twingate setup script completed" >> "$LOG_FILE"
      echo "========================================" >> "$LOG_FILE"

runcmd:
  # Debug: Log that runcmd started and cloud-init info
  - 'echo "$(date): Cloud-init runcmd section started" >> /tmp/cloud-init-runcmd.log'
  - 'echo "$(date): Cloud-init version info" >> /tmp/cloud-init-runcmd.log'
  - 'cloud-init --version >> /tmp/cloud-init-runcmd.log 2>&1 || echo "cloud-init command not available" >> /tmp/cloud-init-runcmd.log'
  
  # Create log directory and set permissions
  - mkdir -p /var/log
  - touch /var/log/twingate-install.log
  - chmod 644 /var/log/twingate-install.log
  
  # Log cloud-init start
  - 'echo "$(date): Cloud-init runcmd section started" >> /var/log/twingate-install.log'
  
  # Debug: Check if twingate-setup.sh was created by write_files
  - 'echo "$(date): Checking for /opt/twingate-setup.sh..." >> /var/log/twingate-install.log'
  - 'ls -la /opt/twingate-setup.sh >> /var/log/twingate-install.log 2>&1 || echo "Setup script not found" >> /var/log/twingate-install.log'
  
  # Execute the Twingate setup script
  - 'echo "$(date): Executing twingate setup script..." >> /var/log/twingate-install.log'
  - /opt/twingate-setup.sh
  
  # Log cloud-init completion
  - 'echo "$(date): Cloud-init runcmd section completed" >> /var/log/twingate-install.log'
  
  # Debug: Create summary of what happened
  - 'echo "$(date): === DEBUG SUMMARY ===" >> /var/log/twingate-install.log'
  - 'echo "$(date): Cloud-init user-data processing completed" >> /var/log/twingate-install.log'
  - 'ls -la /opt/twingate-setup.sh >> /var/log/twingate-install.log 2>&1 || echo "Setup script still missing" >> /var/log/twingate-install.log'
  - 'ls -la /tmp/cloud-init-debug.log >> /var/log/twingate-install.log 2>&1 || echo "Debug log missing" >> /var/log/twingate-install.log'

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
  user_data      = local.user_data

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
  description = "Commands to check Twingate installation"
  value       = var.enable_floating_ip ? "SSH: ssh root@${ibm_is_floating_ip.twingate_fip[0].address} | Check: ls -la /opt/twingate-setup.sh /tmp/cloud-init-*.log | Logs: tail -f /var/log/twingate-install.log" : "SSH: ssh root@${ibm_is_instance.twingate_vsi.primary_network_interface[0].primary_ipv4_address} | Check: ls -la /opt/twingate-setup.sh /tmp/cloud-init-*.log"
}

output "debug_commands" {
  description = "Debug commands if installation fails"
  value       = "cloud-init status; ls -la /opt/twingate-setup.sh /tmp/cloud-init-*.log; tail -20 /var/log/cloud-init-output.log"
}

output "floating_ip_enabled" {
  description = "Whether floating IP is enabled for the instance"
  value       = var.enable_floating_ip
} 