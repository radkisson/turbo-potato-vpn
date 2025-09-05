# Operations Guide

## Initial Deployment

### Prerequisites

1. **Azure Account**: With permissions to create VMs, storage accounts, and key vaults
2. **Tailscale Account**: Create an account at <https://tailscale.com>
3. **Azure OpenAI**: Provision an Azure OpenAI service
4. **Local Tools**:
   - Terraform >= 1.0
   - Ansible >= 2.9
   - SSH key pair

### Step 1: Configure Variables

1. Copy `infrastructure/terraform/terraform.tfvars.example` to `terraform.tfvars`
2. Fill in your specific values:

```hcl
environment           = "prod"
location             = "canadacentral"
vm_size              = "Standard_B2als_v2"
admin_username       = "adminuser"
ssh_public_key_path  = "~/.ssh/id_rsa.pub"
tailscale_auth_key   = "tskey-auth-xxxxxxxxxxxx"
openai_api_key       = "your-azure-openai-key"
openai_api_base      = "https://your-endpoint.openai.azure.com/"
```

### Step 2: Deploy Infrastructure

```bash
cd infrastructure/terraform
terraform init
terraform plan
terraform apply
```

### Step 3: Configure Services

```bash
# Update Ansible inventory with the VM IP
echo "[tailscale-hub]" > infrastructure/ansible/inventory.ini
echo "$(terraform output -raw public_ip_address) ansible_user=adminuser ansible_ssh_private_key_file=~/.ssh/id_rsa" >> infrastructure/ansible/inventory.ini

# Run the setup playbook
cd infrastructure/ansible
ansible-playbook -i inventory.ini playbooks/setup.yml
```

### Step 4: Post-Deployment Configuration

1. **Approve Tailscale Node**: In the Tailscale admin console, approve the new node and enable it as an exit node
2. **Configure AdGuard**: Access AdGuard Home at `http://azure-vm.tailnet:8080` and complete initial setup
3. **Access Open WebUI**: Navigate to `http://azure-vm.tailnet:8081` and configure Azure OpenAI connection

## Daily Operations

### Monitoring Health

```bash
# Check service status
docker compose ps

# View logs
docker compose logs adguard
docker compose logs openwebui
docker compose logs prometheus

# Check Tailscale status
tailscale status
```

### Updating Services

```bash
# Pull latest images
docker compose pull

# Restart services
docker compose up -d --force-recreate
```

### Backup Operations

```bash
# Manual backup
restic backup /opt/tailscale-hub

# Check backup status
restic snapshots

# Restore from backup
restic restore latest --target /opt/restore
```

## Troubleshooting

### Common Issues

#### DNS Not Working

1. Check AdGuard Home status: `docker logs adguard`
2. Verify Unbound is responding: `docker logs unbound`
3. Test DNS resolution: `nslookup google.com 127.0.0.1`

#### Tailscale Connection Issues

1. Check Tailscale status: `tailscale status`
2. Restart Tailscale: `sudo systemctl restart tailscaled`
3. Re-authenticate: `tailscale up --authkey=YOUR_KEY`

#### Open WebUI Not Accessible

1. Check container status: `docker logs openwebui`
2. Verify Azure OpenAI credentials in `.env` file
3. Test API connection manually

### Log Locations

- **System logs**: `/var/log/syslog`
- **Docker logs**: `docker logs <container_name>`
- **Tailscale logs**: `journalctl -u tailscaled`
- **Service logs**: Available in Grafana dashboard

## Maintenance

### Monthly Tasks

1. **Update packages**: `sudo apt update && sudo apt upgrade`
2. **Update Docker images**: `docker compose pull && docker compose up -d`
3. **Review security logs**: Check Fail2ban and UFW logs
4. **Verify backups**: Test restore procedure

### Security Updates

1. **Monitor CVE alerts**: Subscribe to Ubuntu security notices
2. **Update blocklists**: AdGuard Home auto-updates, verify in UI
3. **Review access logs**: Check Tailscale admin console for unusual activity
4. **Rotate secrets**: Update API keys and passwords quarterly
