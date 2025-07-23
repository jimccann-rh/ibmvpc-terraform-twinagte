# Example Terraform variables for IBM Cloud VPC Twingate connector deployment
# Copy this file to terraform.tfvars and customize the values

# IBM Cloud region (optional, default: us-east)
region = "us-east"

# Availability zone (optional, default: us-east-1)
zone = "us-east-1"

# Resource group name (optional, default: default)
resource_group = "Default"

# SSH key name (REQUIRED - must exist in IBM Cloud)
# Create an SSH key in IBM Cloud first: ibmcloud is key-create <key-name> @~/.ssh/id_rsa.pub
#ssh_key_name = "my-ssh-key"

# Instance name (optional, default: twingate-connector-vsi)
instance_name = "twingate-connector"

# Instance profile (optional, default: bx2-2x8)
# Available profiles: bx2-2x8, bx2-4x16, bx2-8x32, etc.
instance_profile = "bx2-2x8"

# Enable floating IP for external access (optional, default: true)
# Set to false if you only need private network access
#enable_floating_ip = false

# Twingate connector configuration (REQUIRED)
# Get these values from your tgconnect file or Twingate admin console
twingate_access_token = "your-twingate-access-token-here"
twingate_refresh_token = "your-twingate-refresh-token-here"
twingate_network = ""  # Your Twingate network name (optional, default: ) 

# Second VSI configuration (optional, default: false)
# Set to true to create a second VSI without cloud-init user data
#create_second_vsi = true
#second_instance_name = "second-vsi"  # Name for the second instance (optional)

