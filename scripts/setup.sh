#!/bin/bash

# Tailscale-Azure VPN & LLM Hub Setup Script
# This script automates the initial setup of the infrastructure

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check if required tools are installed
check_prerequisites() {
    log "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi
    
    if ! command -v ansible &> /dev/null; then
        missing_tools+=("ansible")
    fi
    
    if ! command -v az &> /dev/null; then
        missing_tools+=("azure-cli")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        error "Missing required tools: ${missing_tools[*]}"
    fi
    
    log "All prerequisites met"
}

# Check if configuration files exist
check_configuration() {
    log "Checking configuration files..."
    
    if [ ! -f "infrastructure/terraform/terraform.tfvars" ]; then
        warn "terraform.tfvars not found. Creating from example..."
        cp infrastructure/terraform/terraform.tfvars.example infrastructure/terraform/terraform.tfvars
        error "Please edit infrastructure/terraform/terraform.tfvars with your values"
    fi
    
    if [ ! -f "infrastructure/ansible/inventory.ini" ]; then
        warn "Ansible inventory will be created after Terraform deployment"
    fi
    
    log "Configuration check complete"
}

# Deploy infrastructure with Terraform
deploy_infrastructure() {
    log "Deploying infrastructure with Terraform..."
    
    cd infrastructure/terraform
    
    log "Initializing Terraform..."
    terraform init
    
    log "Planning deployment..."
    terraform plan -out=tfplan
    
    read -p "Do you want to proceed with the deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "Deployment cancelled by user"
    fi
    
    log "Applying Terraform configuration..."
    terraform apply tfplan
    
    # Get the public IP for Ansible
    VM_IP=$(terraform output -raw public_ip_address)
    echo "VM_IP=$VM_IP" > ../../.deployment_vars
    
    cd ../../
    log "Infrastructure deployment complete"
}

# Configure services with Ansible
configure_services() {
    log "Configuring services with Ansible..."
    
    # Source the deployment variables
    source .deployment_vars
    
    # Create Ansible inventory
    cat > infrastructure/ansible/inventory.ini << EOF
[tailscale-hub]
$VM_IP ansible_user=adminuser ansible_ssh_private_key_file=~/.ssh/id_rsa ansible_ssh_common_args='-o StrictHostKeyChecking=no'

[tailscale-hub:vars]
ansible_python_interpreter=/usr/bin/python3
EOF
    
    cd infrastructure/ansible
    
    # Wait for SSH to be available
    log "Waiting for SSH to be available..."
    for i in {1..30}; do
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no adminuser@$VM_IP "echo 'SSH is ready'" 2>/dev/null; then
            break
        fi
        sleep 10
        if [ $i -eq 30 ]; then
            error "SSH connection timeout"
        fi
    done
    
    log "Running Ansible playbook..."
    ansible-playbook -i inventory.ini playbooks/setup.yml
    
    cd ../../
    log "Service configuration complete"
}

# Post-deployment instructions
post_deployment() {
    source .deployment_vars
    
    log "Deployment complete!"
    echo
    echo "Next steps:"
    echo "1. In your Tailscale admin console, approve the new device and enable it as an exit node"
    echo "2. Access AdGuard Home at: http://azure-vm.tailnet:8080"
    echo "3. Access Open WebUI at: http://azure-vm.tailnet:8081"
    echo "4. Access Grafana at: http://azure-vm.tailnet:3001"
    echo
    echo "VM Public IP: $VM_IP"
    echo "Connect to VM: ssh adminuser@$VM_IP"
    echo
    echo "For troubleshooting, see: docs/troubleshooting.md"
}

# Main execution
main() {
    log "Starting Tailscale-Azure VPN & LLM Hub setup..."
    
    check_prerequisites
    check_configuration
    deploy_infrastructure
    configure_services
    post_deployment
    
    log "Setup completed successfully!"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
