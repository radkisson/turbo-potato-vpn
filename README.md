# Tailscale-Azure VPN & LLM Hub

A private, device-agnostic VPN with strong ad and tracker blocking, administered on Azure, controlled over Tailscale, paired with on-premise-friendly workflow for LLM access and content organization.

## Overview

This repository contains the infrastructure code, configuration, and documentation for deploying:

- **Private VPN network** using Tailscale mesh networking
- **DNS-level ad and tracker blocking** with AdGuard Home and Unbound
- **LLM access system** using Open WebUI with Azure OpenAI
- **Security hardening** components for the entire stack
- **Knowledge management** tools for content organization

## Architecture

![Architecture Overview](./docs/diagrams/service-architecture.png)

The system is built around a single Azure VM acting as both a Tailscale exit node and subnet router, with Docker containers providing the core services.

## Quick Start

1. **Prerequisites**
   - Azure account with permissions to create resources
   - Tailscale account
   - Terraform and Ansible installed locally

2. **Deployment**

   ```bash
   # Clone the repository
   git clone https://github.com/radkisson/turbo-potato-vpn.git
   cd turbo-potato-vpn

   # Initialize Terraform
   cd infrastructure/terraform
   terraform init
   terraform apply

   # Run Ansible playbook
   cd ../ansible
   ansible-playbook playbooks/setup.yml
   ```

3. **Access Services**

   - Connect to your Tailscale network
   - AdGuard Home: <http://azure-vm.tailnet:8080>
   - Open WebUI: <http://azure-vm.tailnet:8081>

## Components

### Network & DNS

- Tailscale mesh using WireGuard
- AdGuard Home for DNS policy and blocklists
- Unbound in recursive mode for privacy

### LLM Access

- Open WebUI as frontend
- Azure OpenAI as the model provider

### Security & Reliability

- NSG rules blocking all public inbound traffic
- UFW, Fail2ban, CrowdSec for defense
- Prometheus, Grafana, Loki for monitoring
- Restic backups to Azure Blob

### Knowledge & Content (Optional Extensions)

- Paperless-ngx for documents
- Immich for media
- Meilisearch/Typesense for search
- Qdrant for embeddings

## Documentation

- [Architecture Details](./docs/architecture.md)
- [Operations Guide](./docs/operations.md)
- [Security Hardening](./docs/security.md)
- [Troubleshooting](./docs/troubleshooting.md)

## License

MIT
