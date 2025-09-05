#!/bin/bash

# Tailscale-Azure VPN & LLM Hub Update Script
# This script updates all components of the system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
    exit 1
}

PROJECT_DIR="/opt/tailscale-hub"

# Check if running on the correct system
if [[ ! -d "$PROJECT_DIR" ]]; then
    error "Project directory $PROJECT_DIR not found. This script should run on the Tailscale hub VM."
fi

# Update system packages
update_system() {
    log "Updating system packages..."
    sudo apt update && sudo apt upgrade -y
    sudo apt autoremove -y
    log "System packages updated"
}

# Update Docker images
update_docker_images() {
    log "Updating Docker images..."
    cd "$PROJECT_DIR"
    
    # Pull latest images
    docker compose pull
    
    # Restart services with new images
    docker compose up -d
    
    # Clean up old images
    docker image prune -f
    
    log "Docker images updated"
}

# Update Tailscale
update_tailscale() {
    log "Updating Tailscale..."
    sudo tailscale update
    log "Tailscale updated"
}

# Update AdGuard Home filters
update_adguard_filters() {
    log "Updating AdGuard Home filters..."
    # AdGuard Home automatically updates filters, but we can trigger it
    curl -s "http://localhost:8080/control/filtering/refresh" -H "Content-Type: application/json" -d '{}' || warn "Could not refresh AdGuard filters"
    log "AdGuard filters refresh triggered"
}

# Check service health
check_services() {
    log "Checking service health..."
    cd "$PROJECT_DIR"
    
    # Check if all services are running
    docker compose ps
    
    # Check specific service endpoints
    services=(
        "http://localhost:8080/control/status:AdGuard Home"
        "http://localhost:8081:Open WebUI"
        "http://localhost:9090:Prometheus"
        "http://localhost:3001:Grafana"
        "http://localhost:3100/ready:Loki"
    )
    
    for service in "${services[@]}"; do
        url="${service%:*}"
        name="${service#*:}"
        
        if curl -s -f "$url" > /dev/null 2>&1; then
            log "✓ $name is healthy"
        else
            warn "✗ $name is not responding"
        fi
    done
}

# Main update function
main() {
    log "Starting system update..."
    
    update_system
    update_tailscale
    update_docker_images
    update_adguard_filters
    
    log "Waiting for services to stabilize..."
    sleep 30
    
    check_services
    
    log "Update completed successfully!"
    log "All services should be running with the latest versions"
}

# Handle script interruption
trap 'error "Update script interrupted"' INT

# Run main function
main "$@"
