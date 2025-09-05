# Troubleshooting Guide

## Common Issues and Solutions

### DNS Resolution Problems

#### Symptoms

- Websites not loading
- DNS queries timing out
- Inconsistent connectivity

#### Diagnosis

```bash
# Test DNS resolution
nslookup google.com
dig @127.0.0.1 google.com

# Check AdGuard Home status
docker logs adguard

# Check Unbound status
docker logs unbound

# Verify container connectivity
docker exec adguard ping unbound
```

#### Solutions

1. **Restart DNS services**:

   ```bash
   docker compose restart adguard unbound
   ```

2. **Check configuration files**:

   ```bash
   # Verify Unbound config
   docker exec unbound unbound-checkconf /etc/unbound/unbound.conf
   
   # Check AdGuard config
   docker exec adguard cat /opt/adguardhome/conf/AdGuardHome.yaml
   ```

3. **Reset DNS configuration**:

   ```bash
   # Backup current config
   cp configs/adguard/AdGuardHome.yaml configs/adguard/AdGuardHome.yaml.bak
   
   # Restore default config
   cp configs/adguard/AdGuardHome.yaml.default configs/adguard/AdGuardHome.yaml
   
   docker compose restart adguard
   ```

### Tailscale Connectivity Issues

#### Symptoms

- Cannot access services via Tailscale IPs
- Exit node not working
- Devices not appearing in network

#### Diagnosis

```bash
# Check Tailscale status
tailscale status

# View Tailscale logs
journalctl -u tailscaled -f

# Test connectivity
tailscale ping <device-name>

# Check routes
tailscale status --json | jq '.Self.PrimaryRoutes'
```

#### Solutions

1. **Restart Tailscale**:

   ```bash
   sudo systemctl restart tailscaled
   ```

2. **Re-authenticate**:

   ```bash
   tailscale up --authkey=<your-auth-key> --advertise-exit-node --advertise-routes=10.0.0.0/16 --ssh
   ```

3. **Check firewall rules**:

   ```bash
   # Verify UFW status
   sudo ufw status
   
   # Allow Tailscale interface
   sudo ufw allow in on tailscale0
   ```

4. **Enable IP forwarding**:

   ```bash
   # Check current setting
   cat /proc/sys/net/ipv4/ip_forward
   
   # Enable if disabled
   echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
   echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.conf
   sudo sysctl -p
   ```

### Open WebUI Connection Problems

#### Symptoms

- Cannot access Open WebUI interface
- LLM requests failing
- Authentication errors

#### Diagnosis

```bash
# Check Open WebUI logs
docker logs openwebui

# Test API connectivity
curl -H "Authorization: Bearer $OPENAI_API_KEY" \
     "$OPENAI_API_BASE/v1/models"

# Check environment variables
docker exec openwebui env | grep -i openai
```

#### Solutions

1. **Verify API credentials**:

   ```bash
   # Check .env file
   cat /opt/tailscale-hub/.env
   
   # Update if necessary
   nano /opt/tailscale-hub/.env
   docker compose restart openwebui
   ```

2. **Test Azure OpenAI endpoint**:

   ```bash
   # Test direct API call
   curl -X GET \
   -H "api-key: $OPENAI_API_KEY" \
   "$OPENAI_API_BASE/openai/deployments?api-version=2023-05-15"
   ```

3. **Reset Open WebUI data**:

   ```bash
   # Backup existing data
   sudo cp -r /opt/tailscale-hub/openwebui /opt/tailscale-hub/openwebui.backup
   
   # Remove and recreate
   sudo rm -rf /opt/tailscale-hub/openwebui
   sudo mkdir /opt/tailscale-hub/openwebui
   docker compose restart openwebui
   ```

### Container Issues

#### Symptoms

- Containers not starting
- Services crashing repeatedly
- Resource exhaustion

#### Diagnosis

```bash
# Check container status
docker compose ps

# View resource usage
docker stats

# Check system resources
free -h
df -h
top

# View container logs
docker compose logs --tail=50 <service-name>
```

#### Solutions

1. **Restart problematic services**:

   ```bash
   docker compose restart <service-name>
   ```

2. **Clean up Docker resources**:

   ```bash
   # Remove unused containers
   docker container prune
   
   # Remove unused images
   docker image prune
   
   # Remove unused volumes
   docker volume prune
   
   # Clean everything
   docker system prune -a
   ```

3. **Check disk space**:

   ```bash
   # Check disk usage
   df -h
   
   # Find large files
   sudo find /opt/tailscale-hub -type f -size +100M
   
   # Clean logs if needed
   sudo journalctl --vacuum-time=7d
   ```

### Monitoring and Metrics Issues

#### Symptoms

- Grafana not accessible
- Missing metrics
- Prometheus not scraping targets

#### Diagnosis

```bash
# Check monitoring stack
docker compose ps prometheus grafana loki

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# View Prometheus config
docker exec prometheus cat /etc/prometheus/prometheus.yml

# Check Grafana logs
docker logs grafana
```

#### Solutions

1. **Restart monitoring stack**:

   ```bash
   docker compose restart prometheus grafana loki promtail
   ```

2. **Verify network connectivity**:

   ```bash
   # Test internal network
   docker exec prometheus ping node_exporter
   docker exec grafana ping prometheus
   ```

3. **Reset Grafana admin password**:

   ```bash
   # Update environment variable
   echo "GRAFANA_PASSWORD=newpassword" >> /opt/tailscale-hub/.env
   docker compose restart grafana
   ```

## Performance Optimization

### DNS Performance

1. **Optimize Unbound cache**:

   ```conf
   # In unbound.conf
   msg-cache-size: 100m
   rrset-cache-size: 200m
   num-threads: 4
   ```

2. **AdGuard Home tuning**:

   ```yaml
   # Increase cache size
   dns:
     cache_size: 8388608  # 8MB
     cache_ttl_min: 300   # 5 minutes
   ```

### Container Resource Limits

```yaml
# In docker-compose.yml
services:
  adguard:
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '1.0'
        reservations:
          memory: 256M
          cpus: '0.5'
```

### Storage Optimization

```bash
# Enable log rotation
sudo logrotate -f /etc/logrotate.conf

# Configure Docker log limits
# In /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

## Emergency Procedures

### Complete System Recovery

1. **Boot from backup**:

   ```bash
   # Mount backup disk
   sudo mount /dev/sdb1 /mnt/backup
   
   # Restore configuration
   sudo rsync -av /mnt/backup/opt/tailscale-hub/ /opt/tailscale-hub/
   
   # Restart services
   cd /opt/tailscale-hub
   docker compose up -d
   ```

2. **Network isolation**:

   ```bash
   # Temporarily disable Tailscale
   sudo systemctl stop tailscaled
   
   # Block all traffic except local
   sudo ufw --force reset
   sudo ufw default deny incoming
   sudo ufw default deny outgoing
   sudo ufw allow out on lo
   sudo ufw enable
   ```

3. **Service restoration priority**:

   ```bash
   # 1. Core infrastructure
   docker compose up -d unbound adguard
   
   # 2. Monitoring (for diagnostics)
   docker compose up -d prometheus grafana
   
   # 3. Applications
   docker compose up -d openwebui
   
   # 4. Re-enable Tailscale
   sudo systemctl start tailscaled
   ```

### Data Recovery

```bash
# Restore from Restic backup
export RESTIC_REPOSITORY="azure:container-name"
export RESTIC_PASSWORD="your-password"

# List available snapshots
restic snapshots

# Restore specific snapshot
restic restore <snapshot-id> --target /opt/restore

# Copy restored data
sudo cp -r /opt/restore/opt/tailscale-hub/* /opt/tailscale-hub/
```

## Getting Help

### Log Collection

Create a support bundle:

```bash
#!/bin/bash
# collect-logs.sh

BUNDLE_DIR="/tmp/support-bundle-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BUNDLE_DIR"

# System information
uname -a > "$BUNDLE_DIR/system-info.txt"
df -h > "$BUNDLE_DIR/disk-usage.txt"
free -h > "$BUNDLE_DIR/memory-usage.txt"

# Service status
docker compose ps > "$BUNDLE_DIR/docker-status.txt"
tailscale status > "$BUNDLE_DIR/tailscale-status.txt"

# Logs
docker compose logs > "$BUNDLE_DIR/docker-logs.txt"
journalctl -u tailscaled --since "1 hour ago" > "$BUNDLE_DIR/tailscale-logs.txt"

# Configuration (sanitized)
cp /opt/tailscale-hub/docker-compose.yml "$BUNDLE_DIR/"
cp /opt/tailscale-hub/configs/unbound/unbound.conf "$BUNDLE_DIR/"

# Create archive
tar -czf "$BUNDLE_DIR.tar.gz" -C /tmp "$(basename "$BUNDLE_DIR")"
echo "Support bundle created: $BUNDLE_DIR.tar.gz"
```

### Community Resources

- **GitHub Issues**: Report bugs and request features
- **Documentation**: Updated guides and tutorials
- **Discord/Slack**: Community support channels
- **Stack Overflow**: Tagged questions for specific issues
