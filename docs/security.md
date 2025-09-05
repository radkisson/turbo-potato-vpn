# Security Hardening Guide

## Network Security

### Azure Network Security Group (NSG)

The NSG is configured to deny all inbound traffic from the public internet:

```hcl
security_rule {
  name                       = "DenyAllInbound"
  priority                   = 4096
  direction                  = "Inbound"
  access                     = "Deny"
  protocol                   = "*"
  source_port_range          = "*"
  destination_port_range     = "*"
  source_address_prefix      = "*"
  destination_address_prefix = "*"
}
```

### Host Firewall (UFW)

UFW is configured with restrictive defaults:

- **Incoming**: Deny all
- **Outgoing**: Allow all
- **SSH**: Allow only for initial setup, then disabled

### Tailscale Security

- **Zero Trust**: All access goes through Tailscale
- **MagicDNS**: Internal service discovery
- **ACLs**: Control which devices can access which services

## Application Security

### Service Isolation

All services run in Docker containers with:

- **Non-root users**: Where possible
- **Resource limits**: CPU and memory constraints
- **Network isolation**: Services communicate only as needed

### Secret Management

- **Azure Key Vault**: For sensitive configuration
- **Environment variables**: For runtime secrets
- **File permissions**: Restrictive permissions on config files (600)

### DNS Security

#### AdGuard Home Configuration

- **DNS-over-HTTPS**: Optional upstream encryption
- **DNSSEC**: Validation enabled
- **Malware blocking**: Enabled with multiple blocklists
- **Query logging**: For security analysis

#### Unbound Configuration

- **Recursive resolution**: No reliance on third-party DNS
- **DNSSEC validation**: Cryptographic verification
- **Privacy protection**: No query forwarding to external servers

## System Hardening

### Operating System

```bash
# Automatic security updates
unattended-upgrades

# Fail2ban for intrusion prevention
fail2ban

# System auditing
auditd

# File integrity monitoring
aide
```

### SSH Hardening

Since we use Tailscale SSH, traditional SSH is disabled:

```yaml
- name: Disable SSH password authentication
  lineinfile:
    path: /etc/ssh/sshd_config
    regexp: '^PasswordAuthentication'
    line: 'PasswordAuthentication no'

- name: Disable root login
  lineinfile:
    path: /etc/ssh/sshd_config
    regexp: '^PermitRootLogin'
    line: 'PermitRootLogin no'
```

### Container Security

#### Docker Security

```yaml
# Run containers as non-root
user: "1000:1000"

# Read-only root filesystem where possible
read_only: true

# No new privileges
security_opt:
  - no-new-privileges:true

# Limit capabilities
cap_drop:
  - ALL
cap_add:
  - CHOWN
  - SETGID
  - SETUID
```

## Monitoring and Alerting

### Security Metrics

Monitor these key security indicators:

1. **Failed authentication attempts**
2. **Unusual network traffic patterns**
3. **DNS query anomalies**
4. **Container security events**
5. **File system changes**

### Log Analysis

#### Centralized Logging

All logs are collected by Promtail and stored in Loki:

- **System logs**: `/var/log/syslog`
- **Authentication logs**: `/var/log/auth.log`
- **Application logs**: Docker container logs
- **Security logs**: Fail2ban, UFW logs

#### Alert Rules

```yaml
groups:
  - name: security_alerts
    rules:
      - alert: HighFailedLoginRate
        expr: increase(failed_login_attempts[5m]) > 10
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High rate of failed login attempts"

      - alert: UnusualDNSQueries
        expr: increase(dns_queries_blocked[1h]) > 1000
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Unusual number of blocked DNS queries"
```

## Incident Response

### Detection

1. **Automated monitoring**: Grafana alerts
2. **Log analysis**: Regular review of security logs
3. **Network monitoring**: Tailscale admin console

### Response Procedures

#### Suspected Compromise

1. **Isolate**: Disconnect from Tailscale network
2. **Analyze**: Check logs for indicators of compromise
3. **Contain**: Stop affected services
4. **Eradicate**: Remove malicious content
5. **Recover**: Restore from known good backups
6. **Learn**: Update security measures

#### Service Disruption

1. **Assess**: Determine scope of impact
2. **Communicate**: Notify stakeholders
3. **Mitigate**: Implement workarounds
4. **Restore**: Bring services back online
5. **Review**: Conduct post-incident analysis

## Compliance Considerations

### Data Protection

- **Encryption in transit**: TLS for all communications
- **Encryption at rest**: Azure disk encryption
- **Access controls**: Tailscale ACLs and authentication
- **Audit logging**: Comprehensive logging of all access

### Privacy

- **DNS privacy**: Unbound recursive resolution
- **Query logging**: Can be disabled for privacy
- **No third-party tracking**: All services self-hosted
- **Data retention**: Configurable log retention periods

## Security Updates

### Regular Updates

```bash
#!/bin/bash
# Monthly security update script

# Update package lists
apt update

# Install security updates
unattended-upgrade

# Update Docker images
docker compose pull
docker compose up -d

# Update blocklists
curl -o /tmp/adguard-update.sh https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/hooks/pre-commit.sh
chmod +x /tmp/adguard-update.sh
/tmp/adguard-update.sh
```

### Emergency Procedures

#### Immediate Response

1. **Isolate system**: Disconnect from network
2. **Preserve evidence**: Take memory dump, disk image
3. **Notify stakeholders**: Security team, management
4. **Document**: Timeline of events and actions taken

#### Recovery

1. **Assess damage**: Determine what was compromised
2. **Restore from backup**: Use known good backup
3. **Patch vulnerabilities**: Apply security updates
4. **Monitor**: Enhanced monitoring for continued threats
