# Deployment Checklist

## Pre-Deployment

- [ ] Azure subscription with appropriate permissions
- [ ] Tailscale account created
- [ ] SSH key pair generated (`ssh-keygen -t rsa -b 4096`)
- [ ] Terraform installed (>= 1.0)
- [ ] Ansible installed (>= 2.9)
- [ ] Azure CLI installed (optional)

## Configuration

- [ ] Copy `terraform.tfvars.example` to `terraform.tfvars`
- [ ] Update `terraform.tfvars` with your values:
  - [ ] Azure region
  - [ ] VM size
  - [ ] SSH public key path
  - [ ] Tailscale auth key
  - [ ] Azure OpenAI credentials
- [ ] Review Ansible variables in `infrastructure/ansible/vars/main.yml`
- [ ] Create Ansible vault for sensitive variables (optional)

## Deployment Steps

### 1. Infrastructure Deployment
```bash
cd infrastructure/terraform
terraform init
terraform plan
terraform apply
```

### 2. System Configuration
```bash
# Update inventory with VM IP
# Edit infrastructure/ansible/inventory.ini

cd infrastructure/ansible
ansible-playbook -i inventory.ini playbooks/setup.yml
```

### 3. Service Verification
- [ ] SSH to VM successfully
- [ ] Tailscale connected and advertising routes
- [ ] All Docker containers running
- [ ] DNS resolution working through AdGuard
- [ ] Open WebUI accessible
- [ ] Monitoring stack operational

## Post-Deployment

### Initial Configuration
- [ ] Complete AdGuard Home setup via web interface
- [ ] Configure Open WebUI settings
- [ ] Set up Grafana dashboards
- [ ] Test backup system
- [ ] Configure client devices to use exit node

### Security Verification
- [ ] Verify no public inbound access (except necessary)
- [ ] Confirm fail2ban is active
- [ ] Test firewall rules
- [ ] Verify SSL/TLS certificates
- [ ] Check system update schedule

### Documentation
- [ ] Document any custom configurations
- [ ] Update network diagrams
- [ ] Record service URLs and credentials
- [ ] Create user guides for team members

## Testing Checklist

### Connectivity Tests
- [ ] Tailscale mesh connectivity
- [ ] Exit node functionality
- [ ] DNS resolution and blocking
- [ ] LLM API connectivity
- [ ] Monitoring data collection

### Performance Tests
- [ ] DNS query response times
- [ ] Network throughput via exit node
- [ ] LLM response times
- [ ] System resource utilization

### Security Tests
- [ ] Port scan from external network
- [ ] Authentication bypass attempts
- [ ] Backup encryption verification
- [ ] Log integrity checks

## Maintenance Schedule

### Daily
- [ ] Automated backups running
- [ ] System health monitoring
- [ ] Log aggregation working

### Weekly
- [ ] Security updates applied
- [ ] Backup integrity verification
- [ ] Performance metrics review

### Monthly
- [ ] Access review
- [ ] Capacity planning assessment
- [ ] Disaster recovery testing
