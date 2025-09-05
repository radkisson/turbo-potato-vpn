# Architecture Documentation

## System Architecture

This solution creates a private network hub with the following components:

### Core Network Components

- **Tailscale Mesh Network**: Creates a secure overlay network using WireGuard
- **Azure VM**: Acts as both an exit node and subnet router
- **MagicDNS**: Provides service discovery and split DNS functionality
- **Tailscale ACLs**: Controls access to admin interfaces and services

### DNS and Content Filtering

- **AdGuard Home**: Provides DNS-level ad and tracker blocking with custom policies
- **Unbound**: Acts as a recursive DNS resolver for enhanced privacy
- **Blocklists**: Carefully selected lists to block ads, trackers, and malware

### LLM Access

- **Open WebUI**: Web interface for interacting with language models
- **Azure OpenAI**: Backend service providing the LLM capabilities
- **Configuration**: Custom settings for Azure OpenAI API endpoints

### Security Components

- **Network Security Group (NSG)**: Blocks all inbound traffic from the public internet
- **UFW**: Host-based firewall for additional protection
- **Fail2ban**: Protection against brute force attacks
- **CrowdSec**: Collaborative intrusion defense
- **Tailscale SSH**: Secure remote access without opening SSH ports

### Monitoring and Observability

- **Prometheus**: Metrics collection
- **Grafana**: Visualization and alerting
- **Loki**: Log aggregation
- **Promtail**: Log collection agent
- **cAdvisor**: Container metrics
- **Node Exporter**: Host metrics

### Backup and Recovery

- **Restic**: Backup utility
- **Azure Blob Storage**: Backup destination with lifecycle policies

## Network Flow

1. **Client Devices** connect to the **Tailscale Network**
2. Traffic is routed through the **Azure VM** when using the exit node feature
3. DNS requests go to **AdGuard Home** for filtering
4. **AdGuard Home** forwards queries to **Unbound** for recursive resolution
5. Web requests are allowed or blocked based on DNS filtering rules
6. LLM requests go to **Open WebUI** which communicates with **Azure OpenAI**

## Security Boundaries

- **Public Internet**: No inbound access to the VM
- **Tailscale Network**: Controlled by ACLs, only authorized devices
- **Azure VM**: Hardened with security best practices
- **Service Access**: Internal services bound to localhost, accessible only via Tailscale

## Data Flow

- **DNS Queries**: Client → Tailscale → AdGuard Home → Unbound → Root DNS
- **Web Traffic**: Client → Tailscale Exit Node → Internet
- **LLM Requests**: Client → Tailscale → Open WebUI → Azure OpenAI
- **Metrics**: Services → Prometheus → Grafana
- **Logs**: Services → Promtail → Loki → Grafana

## Component Diagram

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Client Apps   │    │   Client Apps   │    │   Client Apps   │
│                 │    │                 │    │                 │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │    Tailscale Network    │
                    │     (WireGuard VPN)     │
                    └────────────┬────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │      Azure VM Hub       │
                    │  Exit Node + Subnet     │
                    │        Router           │
                    └────────────┬────────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                       │                        │
┌───────▼────────┐    ┌─────────▼─────────┐    ┌─────────▼─────────┐
│   AdGuard +    │    │   Open WebUI     │    │   Monitoring      │
│   Unbound      │    │   + Azure AI     │    │   Stack           │
│   (DNS Filter) │    │   (LLM Access)   │    │   (Observability) │
└────────────────┘    └───────────────────┘    └───────────────────┘
```

## Deployment Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Azure Cloud                             │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                 Resource Group                          │   │
│  │                                                         │   │
│  │  ┌───────────────┐  ┌──────────────┐  ┌──────────────┐ │   │
│  │  │      VM       │  │ Key Vault    │  │ Storage Acc  │ │   │
│  │  │ Ubuntu 22.04  │  │ (Secrets)    │  │ (Backups)    │ │   │
│  │  │               │  │              │  │              │ │   │
│  │  └───────┬───────┘  └──────────────┘  └──────────────┘ │   │
│  │          │                                             │   │
│  │  ┌───────▼───────┐  ┌──────────────┐                  │   │
│  │  │  Data Disk    │  │ Network      │                  │   │
│  │  │  (64GB SSD)   │  │ Security     │                  │   │
│  │  │               │  │ Group        │                  │   │
│  │  └───────────────┘  └──────────────┘                  │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Service Dependencies

```
Tailscale Network
├── DNS Services
│   ├── AdGuard Home (Port 53, 8080)
│   └── Unbound (Port 5335)
├── LLM Services
│   ├── Open WebUI (Port 8081)
│   └── Azure OpenAI (External)
└── Monitoring
    ├── Prometheus (Port 9090)
    ├── Grafana (Port 3001)
    ├── Loki (Port 3100)
    ├── Promtail
    ├── Node Exporter (Port 9100)
    └── cAdvisor (Port 8080)
```
