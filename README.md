# IBM Cloud VPC Twingate Connector Deployment

This Terraform configuration creates an IBM Cloud VPC virtual server instance running CentOS Stream 9 and automatically installs the Twingate connector on first boot using cloud-init.

## Prerequisites

### 1. IBM Cloud CLI and Authentication
```bash
# Install IBM Cloud CLI
curl -fsSL https://clis.cloud.ibm.com/install/linux | sh

# Login to IBM Cloud
ibmcloud login

# Set target region (optional)
ibmcloud target -r us-east
```

### 2. Terraform Installation
```bash
# Install Terraform (Ubuntu/Debian)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

### 3. SSH Key Setup
Create an SSH key in IBM Cloud (required for instance access):
```bash
# Generate SSH key if you don't have one
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# Add SSH key to IBM Cloud
ibmcloud is key-create twingate-connector-key @~/.ssh/id_rsa.pub
```

### 4. IBM Cloud API Key
Set up authentication using one of these methods:

#### Option A: Environment Variable (Recommended)
```bash
export IC_API_KEY="your-ibm-cloud-api-key"
```

#### Option B: IBM Cloud CLI Login
```bash
ibmcloud login
```

## Configuration

### 1. Copy and Customize Variables
```bash
# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit the variables file with your values
vim terraform.tfvars

# IMPORTANT: Add terraform.tfvars to .gitignore (already included in this repo)
# This prevents accidental commit of sensitive tokens
```

### 2. Required Variables
Update `terraform.tfvars` with your values:
```hcl
# REQUIRED: SSH key name (must exist in IBM Cloud)
ssh_key_name = "twingate-connector-key"

# REQUIRED: Twingate connector tokens (from your tgconnect file)
twingate_access_token = "your-twingate-access-token"
twingate_refresh_token = "your-twingate-refresh-token"

# OPTIONAL: Customize these as needed
region = "us-east"
zone = "us-east-1"
resource_group = "default"
instance_name = "twingate-connector"
instance_profile = "bx2-2x8"
enable_floating_ip = true  # Set to false for private-only access
twingate_network = ""  # Your Twingate network name
```

#### Getting Twingate Tokens
Extract the tokens from your `tgconnect` file:
- **Access Token**: The value of `TWINGATE_ACCESS_TOKEN`
- **Refresh Token**: The value of `TWINGATE_REFRESH_TOKEN`
- **Network**: The value of `TWINGATE_NETWORK`

#### Complete Setup Example
```bash
# 1. Copy your tgconnect file contents
cat tgconnect

# 2. Extract the tokens (example from your tgconnect file)
export TWINGATE_ACCESS_TOKEN="eyJhbGciOiJFUzI1NiIsImtpZCI6..."
export TWINGATE_REFRESH_TOKEN="_6eWcxuDbyM8rqwfSccQwILAwb5v..."

# 3. Create terraform.tfvars with your values
cat > terraform.tfvars << EOF
ssh_key_name = "twingate-connector-key"
twingate_access_token = "$TWINGATE_ACCESS_TOKEN"
twingate_refresh_token = "$TWINGATE_REFRESH_TOKEN"
twingate_network = ""
instance_name = "my-twingate-connector"
EOF

# 4. Deploy with Terraform
terraform init
terraform plan
terraform apply
```

## Deployment

### 1. Initialize Terraform
```bash
terraform init
```

### 2. Plan the Deployment
```bash
# Validate configuration
terraform validate

# Plan the deployment (will prompt for missing variables if not set)
terraform plan
```

### 3. Deploy the Infrastructure
```bash
terraform apply
```

### 4. View Outputs
After deployment, Terraform will output useful information:
```bash
# View all outputs
terraform output

# Get specific outputs
terraform output instance_public_ip
terraform output ssh_command
```

## Accessing the Instance

### SSH Access
Use the SSH command from Terraform output:
```bash
# Get the SSH command
terraform output ssh_command

# Example output: ssh root@169.xx.xx.xx
ssh root@<public_ip>
```

### Check Twingate Installation
```bash
# Check installation log
tail -f /var/log/twingate-install.log

# Check connector service status
systemctl status twingate-connector

# Check cloud-init status
cloud-init status
```

## Architecture

This Terraform configuration creates:

### Network Infrastructure
- **VPC**: Isolated virtual network
- **Subnet**: Private subnet with 64 IP addresses
- **Public Gateway**: Internet access for the subnet
- **Security Group**: Firewall rules for SSH and Twingate traffic
- **Floating IP**: Public IP address for external access (enabled by default)

### Compute Resources
- **Virtual Server Instance**: CentOS Stream 9 with Twingate connector
- **Cloud-Init**: Automated Twingate installation on first boot

### Security Groups Rules
- **Inbound SSH (Port 22)**: Access from anywhere
- **Outbound HTTPS (Port 443)**: Twingate communication
- **Outbound HTTP (Port 80)**: Package downloads
- **Outbound DNS (Port 53)**: Name resolution

## Files Created

- `terraibmvpc.tf` - Main Terraform configuration
- `terraform.tfvars.example` - Example variables file
- `README-IBM-Terraform.md` - This documentation
- `.gitignore` - Prevents sensitive files from being committed to version control

## Operating System

This configuration uses **CentOS Stream 9** (`ibm-centos-stream-9-amd64-11`) which provides:
- Enterprise-grade stability and security
- Full compatibility with Red Hat Enterprise Linux (RHEL)
- Latest features and updates from the CentOS Stream project
- Systemd service management
- DNF package manager (modern replacement for YUM)

The cloud-init script is optimized for CentOS/RHEL using `dnf` for package management.

## Customization

### Instance Profiles
Available IBM Cloud instance profiles:
- `bx2-2x8` - 2 vCPUs, 8 GB RAM (default)
- `bx2-4x16` - 4 vCPUs, 16 GB RAM
- `bx2-8x32` - 8 vCPUs, 32 GB RAM
- `bx2-16x64` - 16 vCPUs, 64 GB RAM

### Regions and Zones
Available regions:
- `us-south` (Dallas) - zones: us-south-1, us-south-2, us-south-3
- `us-east` (Washington DC) - zones: us-east-1, us-east-2, us-east-3
- `eu-gb` (London) - zones: eu-gb-1, eu-gb-2, eu-gb-3
- `eu-de` (Frankfurt) - zones: eu-de-1, eu-de-2, eu-de-3
- `jp-tok` (Tokyo) - zones: jp-tok-1, jp-tok-2, jp-tok-3

### Twingate Configuration
The Twingate connector is configured with:
- **Network**: ``
- **Access Token**: From your `tgconnect` file
- **Refresh Token**: From your `tgconnect` file
- **Deployment Label**: `terraform-ibm`

## Troubleshooting

### Common Issues

1. **SSH Key Not Found**
   ```bash
   # List available SSH keys
   ibmcloud is keys
   
   # Create new SSH key
   ibmcloud is key-create my-key @~/.ssh/id_rsa.pub
   ```

2. **Authentication Errors**
   ```bash
   # Check authentication
   ibmcloud target
   
   # Re-login if needed
   ibmcloud login
   ```

3. **Resource Group Issues**
   ```bash
   # List available resource groups
   ibmcloud resource groups
   ```

4. **Twingate Installation Failed**
   ```bash
   # SSH to the instance and check logs
   ssh root@<public_ip>
   tail -f /var/log/twingate-install.log
   tail -f /var/log/cloud-init-output.log
   ```

### Debugging Commands

```bash
# Check Terraform state
terraform state list

# Show specific resource
terraform state show ibm_is_instance.twingate_vsi

# Check cloud-init logs on the instance
ssh root@<public_ip> 'tail -f /var/log/cloud-init.log'

# Check system logs
ssh root@<public_ip> 'journalctl -f'
```

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

## Cost Estimation

Estimated monthly costs (US East region):
- Virtual Server Instance (bx2-2x8): ~$30-40/month
- Floating IP: ~$5/month
- VPC resources: Minimal cost
- **Total**: ~$35-45/month

## Security Considerations

1. **SSH Access**: Restricted to port 22, consider limiting source IPs
2. **Firewall**: Only necessary ports are open
3. **Updates**: Instance will auto-update packages on first boot
4. **Secrets Management**: Twingate tokens are now stored as Terraform variables

### Handling Sensitive Variables

#### Option 1: Environment Variables (Recommended for CI/CD)
```bash
export TF_VAR_twingate_access_token="your-access-token"
export TF_VAR_twingate_refresh_token="your-refresh-token"
terraform apply
```

#### Option 2: Separate tfvars file for secrets
```bash
# Create a separate file for sensitive values
echo 'twingate_access_token = "your-token"' > secrets.tfvars
echo 'twingate_refresh_token = "your-token"' >> secrets.tfvars

# Apply with multiple tfvars files
terraform apply -var-file="terraform.tfvars" -var-file="secrets.tfvars"

# Add secrets.tfvars to .gitignore
echo "secrets.tfvars" >> .gitignore
```

#### Option 3: Interactive input
```bash
# Terraform will prompt for missing variables
terraform apply
```

#### Option 4: IBM Secret Manager (Production)
For production deployments, consider using IBM Secret Manager to store tokens securely.

## Support

For issues with:
- **Terraform**: Check Terraform documentation
- **IBM Cloud**: Contact IBM Cloud support
- **Twingate**: Contact Twingate support

## Advanced Configuration

### Using IBM Secret Manager
For production deployments, consider storing Twingate tokens in IBM Secret Manager:

```hcl
# Add to terraibmvpc.tf

# Data sources to read secrets from IBM Secret Manager
data "ibm_sm_secret" "twingate_access_token" {
  instance_id = "your-secret-manager-instance-id"
  secret_id   = "twingate-access-token"
}

data "ibm_sm_secret" "twingate_refresh_token" {
  instance_id = "your-secret-manager-instance-id"
  secret_id   = "twingate-refresh-token"
}

# Update the variables to use the secrets
locals {
  twingate_access_token  = data.ibm_sm_secret.twingate_access_token.secret_data
  twingate_refresh_token = data.ibm_sm_secret.twingate_refresh_token.secret_data
}

# Use locals in the cloud-init script instead of var.twingate_*_token
```

### Custom Cloud-Init
You can modify the cloud-init configuration in the `locals` block to add additional setup steps or configurations.

### Floating IP Configuration
The VSI is configured with a floating IP (public IP address) by default for external access:

```hcl
# Enable floating IP (default: true)
enable_floating_ip = true

# Disable floating IP for private-only access
enable_floating_ip = false
```

**With Floating IP Enabled (default):**
- VSI gets a public IP address for external access
- SSH access from the internet
- Twingate connector can be managed remotely
- Additional cost: ~$5/month for the floating IP

**With Floating IP Disabled:**
- VSI only has private IP address
- Access only through VPN, bastion host, or IBM Cloud private network
- Lower cost (no floating IP charges)
- More secure (no direct internet access)

The Terraform outputs will automatically adjust based on your floating IP setting. 
