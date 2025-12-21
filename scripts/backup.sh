#!/usr/bin/env bash
# ============================================================================
# Orion-Sentinel-DataAICore Backup Script
# Backs up critical data for disaster recovery
#
# Usage:
#   ./scripts/backup.sh [destination]
#
# Default destination: ~/backups/dataaicore
#
# ============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$REPO_ROOT"

# Helper functions
info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

success() {
    echo -e "${GREEN}✓${NC} $*"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $*"
}

error() {
    echo -e "${RED}✗${NC} $*"
    exit 1
}

# ============================================================================
# Configuration
# ============================================================================

# Load environment
if [ -f ".env" ]; then
    source .env 2>/dev/null || true
fi

DATA_ROOT="${DATA_ROOT:-/srv/orion/dataaicore}"
BACKUP_DIR="${1:-$HOME/backups/dataaicore}"
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="dataaicore-backup-$DATE"

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              DataAICore Backup                                 ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# ============================================================================
# Pre-flight checks
# ============================================================================

info "Checking prerequisites..."

# Check DATA_ROOT exists
if [ ! -d "$DATA_ROOT" ]; then
    error "DATA_ROOT not found: $DATA_ROOT"
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"
success "Backup directory: $BACKUP_DIR"
echo ""

# ============================================================================
# Backup Nextcloud Database
# ============================================================================

info "Backing up Nextcloud database..."

if docker ps --format '{{.Names}}' | grep -q "orion_dataaicore_postgres"; then
    POSTGRES_USER="${POSTGRES_USER:-nextcloud}"
    POSTGRES_DB="${POSTGRES_DB:-nextcloud}"
    
    docker exec orion_dataaicore_postgres pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" | \
        gzip > "$BACKUP_DIR/${BACKUP_NAME}_postgres.sql.gz"
    
    success "Database backup: ${BACKUP_NAME}_postgres.sql.gz"
else
    warn "PostgreSQL container not running - skipping database backup"
fi

echo ""

# ============================================================================
# Backup Configuration
# ============================================================================

info "Backing up configuration files..."

tar -czf "$BACKUP_DIR/${BACKUP_NAME}_config.tar.gz" \
    .env \
    stacks/websearch/searxng/settings.yml 2>/dev/null || true

success "Configuration backup: ${BACKUP_NAME}_config.tar.gz"
echo ""

# ============================================================================
# Backup Nextcloud Application Data (Optional - can be large)
# ============================================================================

info "Nextcloud app/data backup (optional)..."
warn "Skipping Nextcloud app/data - can be very large!"
warn "To backup manually:"
echo "  sudo tar -czf $BACKUP_DIR/${BACKUP_NAME}_nextcloud_app.tar.gz $DATA_ROOT/nextcloud/app"
echo "  sudo tar -czf $BACKUP_DIR/${BACKUP_NAME}_nextcloud_data.tar.gz $DATA_ROOT/nextcloud/data"
echo ""

# ============================================================================
# Backup Open WebUI Data
# ============================================================================

info "Backing up Open WebUI data..."

if [ -d "$DATA_ROOT/llm/openwebui" ]; then
    sudo tar -czf "$BACKUP_DIR/${BACKUP_NAME}_openwebui.tar.gz" \
        "$DATA_ROOT/llm/openwebui" 2>/dev/null || warn "Failed to backup Open WebUI data"
    success "Open WebUI backup: ${BACKUP_NAME}_openwebui.tar.gz"
else
    warn "Open WebUI data not found - skipping"
fi

echo ""

# ============================================================================
# Cleanup old backups
# ============================================================================

info "Cleaning up old backups (keeping last 7 days)..."
find "$BACKUP_DIR" -type f -name "dataaicore-backup-*" -mtime +7 -delete 2>/dev/null || true
success "Old backups cleaned up"
echo ""

# ============================================================================
# Summary
# ============================================================================

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                  Backup Complete!                              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

success "Backup saved to: $BACKUP_DIR"
echo ""

info "Backup contents:"
find "$BACKUP_DIR" -type f -name "${BACKUP_NAME}*" -exec ls -lh {} \; 2>/dev/null || true
echo ""

info "To restore from this backup:"
echo "  ./scripts/restore.sh $BACKUP_DIR/$BACKUP_NAME"
echo ""

warn "IMPORTANT: Store backups securely and test restoration regularly!"
echo ""
