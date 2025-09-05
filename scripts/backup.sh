#!/bin/bash

# Backup script for Tailscale-Azure VPN & LLM Hub
# This script creates backups using Restic

set -euo pipefail

# Configuration
BACKUP_DIR="/opt/tailscale-hub"
RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-}"
RESTIC_PASSWORD="${RESTIC_PASSWORD:-}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
RETENTION_WEEKS="${RETENTION_WEEKS:-4}"
RETENTION_MONTHS="${RETENTION_MONTHS:-12}"

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

# Check if Restic is installed
check_restic() {
    if ! command -v restic &> /dev/null; then
        log "Installing Restic..."
        wget -O /tmp/restic.bz2 https://github.com/restic/restic/releases/latest/download/restic_*_linux_amd64.bz2
        bunzip2 /tmp/restic.bz2
        sudo mv /tmp/restic /usr/local/bin/
        sudo chmod +x /usr/local/bin/restic
    fi
}

# Initialize repository if it doesn't exist
init_repository() {
    if [ -z "$RESTIC_REPOSITORY" ] || [ -z "$RESTIC_PASSWORD" ]; then
        error "RESTIC_REPOSITORY and RESTIC_PASSWORD must be set"
    fi
    
    export RESTIC_REPOSITORY RESTIC_PASSWORD
    
    # Check if repository exists
    if ! restic snapshots &>/dev/null; then
        log "Initializing Restic repository..."
        restic init
    fi
}

# Create pre-backup snapshot of running services
pre_backup() {
    log "Creating pre-backup snapshot..."
    
    # Save running container state
    docker compose ps --format json > "$BACKUP_DIR/container-state.json"
    
    # Save current configuration
    cp -r "$BACKUP_DIR"/.env "$BACKUP_DIR"/backup-metadata/ 2>/dev/null || true
    mkdir -p "$BACKUP_DIR"/backup-metadata
    date > "$BACKUP_DIR"/backup-metadata/backup-timestamp
    docker --version > "$BACKUP_DIR"/backup-metadata/docker-version
    docker compose version > "$BACKUP_DIR"/backup-metadata/compose-version
}

# Stop services for consistent backup
stop_services() {
    log "Stopping services for consistent backup..."
    cd "$BACKUP_DIR"
    docker compose stop
}

# Start services after backup
start_services() {
    log "Starting services after backup..."
    cd "$BACKUP_DIR"
    docker compose up -d
}

# Perform the backup
backup() {
    log "Creating backup..."
    
    # Exclude temporary files and logs
    restic backup "$BACKUP_DIR" \
        --exclude="$BACKUP_DIR"/*/logs/* \
        --exclude="$BACKUP_DIR"/*/tmp/* \
        --exclude="$BACKUP_DIR"/*/.cache/* \
        --exclude="*.log" \
        --tag="automated-backup"
    
    if [ $? -eq 0 ]; then
        log "Backup completed successfully"
    else
        error "Backup failed"
    fi
}

# Clean old backups
cleanup() {
    log "Cleaning up old backups..."
    
    restic forget \
        --keep-daily "$RETENTION_DAYS" \
        --keep-weekly "$RETENTION_WEEKS" \
        --keep-monthly "$RETENTION_MONTHS" \
        --prune
    
    log "Cleanup completed"
}

# Check backup integrity
verify() {
    log "Verifying backup integrity..."
    restic check
    log "Backup verification completed"
}

# Send notification (if configured)
send_notification() {
    local status=$1
    local message=$2
    
    # Example: Send to webhook if configured
    if [ -n "${WEBHOOK_URL:-}" ]; then
        curl -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"status\": \"$status\", \"message\": \"$message\", \"timestamp\": \"$(date -Iseconds)\"}" \
            &>/dev/null || true
    fi
    
    # Example: Send email if configured
    if [ -n "${EMAIL_TO:-}" ] && command -v mail &> /dev/null; then
        echo "$message" | mail -s "Backup $status - Tailscale Hub" "$EMAIL_TO" || true
    fi
}

# Main backup function
main() {
    local skip_stop="${1:-false}"
    
    log "Starting backup process..."
    
    check_restic
    init_repository
    pre_backup
    
    if [ "$skip_stop" != "true" ]; then
        stop_services
    fi
    
    # Perform backup with error handling
    if backup; then
        cleanup
        verify
        send_notification "SUCCESS" "Backup completed successfully at $(date)"
        log "Backup process completed successfully"
    else
        send_notification "FAILED" "Backup failed at $(date)"
        error "Backup process failed"
    fi
    
    if [ "$skip_stop" != "true" ]; then
        start_services
    fi
}

# Usage information
usage() {
    echo "Usage: $0 [--no-stop]"
    echo "  --no-stop    Don't stop services during backup (less consistent but no downtime)"
    echo
    echo "Environment variables:"
    echo "  RESTIC_REPOSITORY  Restic repository URL (required)"
    echo "  RESTIC_PASSWORD    Restic repository password (required)"
    echo "  RETENTION_DAYS     Days to keep daily backups (default: 30)"
    echo "  RETENTION_WEEKS    Weeks to keep weekly backups (default: 4)"
    echo "  RETENTION_MONTHS   Months to keep monthly backups (default: 12)"
    echo "  WEBHOOK_URL        Webhook URL for notifications (optional)"
    echo "  EMAIL_TO           Email address for notifications (optional)"
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        usage
        exit 0
        ;;
    --no-stop)
        main true
        ;;
    *)
        main false
        ;;
esac
