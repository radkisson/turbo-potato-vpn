#!/bin/bash

# Update script for Tailscale-Azure VPN & LLM Hub
# This script updates Docker images and configurations

set -euo pipefail

# Configuration
PROJECT_DIR="/opt/tailscale-hub"
BACKUP_BEFORE_UPDATE="${BACKUP_BEFORE_UPDATE:-true}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check if running as root or with sudo
check_permissions() {
    if [[ $EUID -eq 0 ]]; then
        warn "Running as root. This may cause permission issues with Docker volumes."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Backup before update
backup_before_update() {
    if [ "$BACKUP_BEFORE_UPDATE" = "true" ]; then
        log "Creating backup before update..."
        if [ -f "scripts/backup.sh" ]; then
            ./scripts/backup.sh --no-stop
        else
            warn "Backup script not found. Skipping backup."
        fi
    fi
}

# Check Docker and Docker Compose
check_docker() {
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed or not in PATH"
    fi
    
    if ! docker compose version &> /dev/null && ! command -v docker-compose &> /dev/null; then
        error "Docker Compose is not available"
    fi
    
    # Test Docker access
    if ! docker ps &> /dev/null; then
        error "Cannot access Docker. Make sure Docker is running and you have permission to use it."
    fi
}

# Get current image versions
get_current_versions() {
    log "Getting current image versions..."
    cd "$PROJECT_DIR"
    
    # Extract image versions from docker-compose.yml and running containers
    info "Current running versions:"
    docker compose ps --format "table {{.Name}}\t{{.Image}}\t{{.Status}}"
}

# Pull latest images
pull_images() {
    log "Pulling latest Docker images..."
    cd "$PROJECT_DIR"
    
    # Pull latest images
    docker compose pull
    
    if [ $? -eq 0 ]; then
        log "Successfully pulled latest images"
    else
        error "Failed to pull some images"
    fi
}

# Check for image updates
check_updates() {
    log "Checking for available updates..."
    cd "$PROJECT_DIR"
    
    # Get list of services
    local services=$(docker compose config --services)
    local updates_available=false
    
    for service in $services; do
        local current_id=$(docker compose images -q "$service" 2>/dev/null)
        
        if [ -n "$current_id" ]; then
            # Pull latest and compare
            local image=$(docker compose config | grep -A 10 "^  $service:" | grep "image:" | head -1 | awk '{print $2}')
            if [ -n "$image" ]; then
                docker pull "$image" >/dev/null 2>&1
                local latest_id=$(docker images -q "$image" 2>/dev/null)
                
                if [ "$current_id" != "$latest_id" ]; then
                    info "Update available for $service: $image"
                    updates_available=true
                fi
            fi
        fi
    done
    
    if [ "$updates_available" = false ]; then
        log "All images are up to date"
        return 1
    fi
    
    return 0
}

# Update Docker images
update_images() {
    log "Updating Docker images..."
    cd "$PROJECT_DIR"
    
    # Pull latest images
    pull_images
    
    # Restart services with new images
    log "Restarting services with updated images..."
    docker compose up -d --force-recreate
    
    # Wait for services to be healthy
    log "Waiting for services to start..."
    sleep 30
    
    # Check service health
    check_service_health
}

# Update system packages
update_system() {
    log "Updating system packages..."
    
    # Update package lists
    sudo apt update
    
    # Upgrade packages
    sudo apt upgrade -y
    
    # Clean up
    sudo apt autoremove -y
    sudo apt autoclean
    
    log "System packages updated"
}

# Update blocklists
update_blocklists() {
    log "Updating AdGuard Home blocklists..."
    
    # This would typically be done through AdGuard Home's API
    # For now, we'll just restart AdGuard to trigger an update
    docker compose restart adguard
    
    log "AdGuard Home restarted to update blocklists"
}

# Check service health after update
check_service_health() {
    log "Checking service health..."
    cd "$PROJECT_DIR"
    
    local failed_services=()
    local services=$(docker compose ps --services)
    
    for service in $services; do
        local status=$(docker compose ps "$service" --format "{{.Status}}")
        if [[ ! "$status" =~ "Up" ]]; then
            failed_services+=("$service")
        fi
    done
    
    if [ ${#failed_services[@]} -eq 0 ]; then
        log "All services are healthy"
    else
        warn "The following services are not running properly: ${failed_services[*]}"
        info "Service status:"
        docker compose ps
        
        # Show logs for failed services
        for service in "${failed_services[@]}"; do
            warn "Logs for $service:"
            docker compose logs --tail=20 "$service"
        done
    fi
}

# Clean up old Docker resources
cleanup_docker() {
    log "Cleaning up old Docker resources..."
    
    # Remove dangling images
    docker image prune -f
    
    # Remove unused volumes (be careful with this)
    read -p "Remove unused Docker volumes? This may delete data! (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker volume prune -f
    fi
    
    # Remove unused networks
    docker network prune -f
    
    log "Docker cleanup completed"
}

# Show update summary
show_summary() {
    log "Update Summary:"
    cd "$PROJECT_DIR"
    
    info "Updated services:"
    docker compose ps --format "table {{.Name}}\t{{.Image}}\t{{.Status}}"
    
    info "System information:"
    echo "Docker version: $(docker --version)"
    echo "Docker Compose version: $(docker compose version --short 2>/dev/null || docker-compose --version)"
    echo "Free disk space: $(df -h / | awk 'NR==2{print $4}')"
    echo "Memory usage: $(free -h | awk 'NR==2{printf "%.1f/%.1fGB (%.1f%%)\n", $3/1024/1024, $2/1024/1024, $3*100/$2}')"
}

# Rollback function
rollback() {
    warn "Rolling back to previous version..."
    
    if [ -f "scripts/restore.sh" ]; then
        ./scripts/restore.sh latest --no-start
        start_services
        check_service_health
        log "Rollback completed"
    else
        error "Restore script not found. Manual rollback required."
    fi
}

# Main update function
main() {
    local update_type="${1:-all}"
    local force="${2:-false}"
    
    log "Starting update process..."
    
    check_permissions
    check_docker
    
    case "$update_type" in
        all)
            backup_before_update
            get_current_versions
            
            if check_updates || [ "$force" = "--force" ]; then
                update_images
                update_system
                update_blocklists
                cleanup_docker
                show_summary
            else
                log "No updates available"
            fi
            ;;
        images)
            backup_before_update
            get_current_versions
            update_images
            show_summary
            ;;
        system)
            update_system
            ;;
        blocklists)
            update_blocklists
            ;;
        check)
            get_current_versions
            check_updates
            ;;
        rollback)
            rollback
            ;;
        *)
            echo "Usage: $0 [all|images|system|blocklists|check|rollback] [--force]"
            echo
            echo "Commands:"
            echo "  all         Update everything (default)"
            echo "  images      Update Docker images only"
            echo "  system      Update system packages only"
            echo "  blocklists  Update AdGuard Home blocklists"
            echo "  check       Check for available updates"
            echo "  rollback    Rollback to previous version"
            echo
            echo "Options:"
            echo "  --force     Force update even if no updates detected"
            exit 1
            ;;
    esac
    
    log "Update process completed"
}

# Error handling
trap 'error "Update failed at line $LINENO"' ERR

# Run main function
main "$@"
