#!/bin/bash

# Restore script for Tailscale-Azure VPN & LLM Hub
# This script restores from Restic backups

set -euo pipefail

# Configuration
BACKUP_DIR="/opt/tailscale-hub"
RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-}"
RESTIC_PASSWORD="${RESTIC_PASSWORD:-}"
RESTORE_TARGET="${RESTORE_TARGET:-/opt/restore}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

# Check if Restic is available
check_restic() {
    if ! command -v restic &> /dev/null; then
        error "Restic is not installed. Please install it first."
    fi
}

# Validate repository access
check_repository() {
    if [ -z "$RESTIC_REPOSITORY" ] || [ -z "$RESTIC_PASSWORD" ]; then
        error "RESTIC_REPOSITORY and RESTIC_PASSWORD must be set"
    fi
    
    export RESTIC_REPOSITORY RESTIC_PASSWORD
    
    if ! restic snapshots &>/dev/null; then
        error "Cannot access Restic repository. Check your credentials and network connection."
    fi
}

# List available snapshots
list_snapshots() {
    log "Available snapshots:"
    restic snapshots --compact
}

# Get the latest snapshot ID
get_latest_snapshot() {
    restic snapshots --json | jq -r '.[0].id' 2>/dev/null || echo ""
}

# Restore from snapshot
restore_snapshot() {
    local snapshot_id=$1
    local target_dir=$2
    
    log "Restoring snapshot $snapshot_id to $target_dir..."
    
    # Create target directory
    sudo mkdir -p "$target_dir"
    
    # Restore the snapshot
    restic restore "$snapshot_id" --target "$target_dir"
    
    if [ $? -eq 0 ]; then
        log "Restore completed successfully"
    else
        error "Restore failed"
    fi
}

# Stop running services
stop_services() {
    log "Stopping current services..."
    cd "$BACKUP_DIR" 2>/dev/null || true
    if [ -f docker-compose.yml ]; then
        docker compose down
    fi
}

# Backup current installation
backup_current() {
    if [ -d "$BACKUP_DIR" ]; then
        local backup_name="/opt/tailscale-hub-backup-$(date +%Y%m%d-%H%M%S)"
        log "Backing up current installation to $backup_name..."
        sudo cp -r "$BACKUP_DIR" "$backup_name"
        echo "Current installation backed up to: $backup_name"
    fi
}

# Replace current installation
replace_installation() {
    local restore_path=$1
    
    stop_services
    backup_current
    
    log "Replacing current installation..."
    
    # Remove current installation
    if [ -d "$BACKUP_DIR" ]; then
        sudo rm -rf "$BACKUP_DIR"
    fi
    
    # Move restored files
    sudo mv "$restore_path$BACKUP_DIR" "$BACKUP_DIR"
    
    # Fix permissions
    sudo chown -R $(whoami):$(whoami) "$BACKUP_DIR"
    
    log "Installation replaced successfully"
}

# Start services after restore
start_services() {
    log "Starting restored services..."
    cd "$BACKUP_DIR"
    
    if [ -f docker-compose.yml ]; then
        # Pull any missing images
        docker compose pull
        
        # Start services
        docker compose up -d
        
        log "Services started successfully"
    else
        warn "docker-compose.yml not found. You may need to start services manually."
    fi
}

# Verify restore integrity
verify_restore() {
    log "Verifying restored installation..."
    
    # Check if key files exist
    local required_files=(
        "$BACKUP_DIR/docker-compose.yml"
        "$BACKUP_DIR/configs/unbound/unbound.conf"
        "$BACKUP_DIR/configs/adguard/AdGuardHome.yaml"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            warn "Required file missing: $file"
        fi
    done
    
    # Check if services are responding
    sleep 30  # Give services time to start
    
    if docker compose ps | grep -q "Up"; then
        log "Services are running"
    else
        warn "Some services may not be running properly"
    fi
}

# Interactive snapshot selection
select_snapshot() {
    list_snapshots
    echo
    read -p "Enter snapshot ID (or 'latest' for most recent): " snapshot_input
    
    if [ "$snapshot_input" = "latest" ]; then
        local latest_id=$(get_latest_snapshot)
        if [ -n "$latest_id" ]; then
            echo "$latest_id"
        else
            error "No snapshots found"
        fi
    else
        echo "$snapshot_input"
    fi
}

# Point-in-time recovery
point_in_time_restore() {
    local date_filter=$1
    
    log "Finding snapshots from $date_filter..."
    
    # Find snapshots from specific date
    local snapshot_id=$(restic snapshots --json | jq -r ".[] | select(.time | startswith(\"$date_filter\")) | .id" | head -1)
    
    if [ -n "$snapshot_id" ]; then
        echo "$snapshot_id"
    else
        error "No snapshots found for date: $date_filter"
    fi
}

# Usage information
usage() {
    echo "Usage: $0 [OPTIONS] [COMMAND]"
    echo
    echo "Commands:"
    echo "  list                    List available snapshots"
    echo "  restore [SNAPSHOT_ID]   Restore from specific snapshot (interactive if no ID provided)"
    echo "  latest                  Restore from latest snapshot"
    echo "  date YYYY-MM-DD         Restore from specific date"
    echo "  extract SNAPSHOT_ID     Extract snapshot to temp location without replacing current install"
    echo
    echo "Options:"
    echo "  --target DIR           Restore target directory (default: $RESTORE_TARGET)"
    echo "  --no-replace           Don't replace current installation"
    echo "  --no-start             Don't start services after restore"
    echo
    echo "Environment variables:"
    echo "  RESTIC_REPOSITORY      Restic repository URL (required)"
    echo "  RESTIC_PASSWORD        Restic repository password (required)"
    echo "  RESTORE_TARGET         Default restore target directory"
}

# Main function
main() {
    local command="${1:-}"
    local replace_install=true
    local start_services_flag=true
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --target)
                RESTORE_TARGET="$2"
                shift 2
                ;;
            --no-replace)
                replace_install=false
                shift
                ;;
            --no-start)
                start_services_flag=false
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                break
                ;;
        esac
    done
    
    command="${1:-}"
    
    check_restic
    check_repository
    
    case "$command" in
        list)
            list_snapshots
            ;;
        latest)
            local snapshot_id=$(get_latest_snapshot)
            if [ -n "$snapshot_id" ]; then
                restore_snapshot "$snapshot_id" "$RESTORE_TARGET"
                if [ "$replace_install" = true ]; then
                    replace_installation "$RESTORE_TARGET"
                    if [ "$start_services_flag" = true ]; then
                        start_services
                        verify_restore
                    fi
                fi
            else
                error "No snapshots found"
            fi
            ;;
        restore)
            local snapshot_id="${2:-}"
            if [ -z "$snapshot_id" ]; then
                snapshot_id=$(select_snapshot)
            fi
            restore_snapshot "$snapshot_id" "$RESTORE_TARGET"
            if [ "$replace_install" = true ]; then
                replace_installation "$RESTORE_TARGET"
                if [ "$start_services_flag" = true ]; then
                    start_services
                    verify_restore
                fi
            fi
            ;;
        date)
            local date_filter="${2:-}"
            if [ -z "$date_filter" ]; then
                error "Please specify a date in YYYY-MM-DD format"
            fi
            local snapshot_id=$(point_in_time_restore "$date_filter")
            restore_snapshot "$snapshot_id" "$RESTORE_TARGET"
            if [ "$replace_install" = true ]; then
                replace_installation "$RESTORE_TARGET"
                if [ "$start_services_flag" = true ]; then
                    start_services
                    verify_restore
                fi
            fi
            ;;
        extract)
            local snapshot_id="${2:-}"
            if [ -z "$snapshot_id" ]; then
                snapshot_id=$(select_snapshot)
            fi
            restore_snapshot "$snapshot_id" "$RESTORE_TARGET"
            log "Snapshot extracted to $RESTORE_TARGET"
            ;;
        "")
            usage
            ;;
        *)
            error "Unknown command: $command"
            ;;
    esac
}

# Run main function with all arguments
main "$@"
