#!/usr/bin/env bash
# ============================================================================
# Orion-Sentinel-DataAICore Restore Script
# Restores data from backup
#
# Usage:
#   ./scripts/restore.sh <backup-name-prefix>
#
# Example:
#   ./scripts/restore.sh ~/backups/dataaicore/dataaicore-backup-20241221-120000
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

if [ $# -lt 1 ]; then
    error "Usage: $0 <backup-name-prefix>"
fi

BACKUP_PREFIX="$1"

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              DataAICore Restore                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

warn "⚠️  WARNING: This will REPLACE existing data!"
warn "⚠️  Make sure you have a current backup before proceeding!"
echo ""
read -p "Continue with restore? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Restore cancelled."
    exit 0
fi
echo ""

# Load environment
if [ -f ".env" ]; then
    source .env 2>/dev/null || true
fi

DATA_ROOT="${DATA_ROOT:-/srv/orion/dataaicore}"

# ============================================================================
# Pre-flight checks
# ============================================================================

info "Checking backup files..."

DB_BACKUP="${BACKUP_PREFIX}_postgres.sql.gz"
CONFIG_BACKUP="${BACKUP_PREFIX}_config.tar.gz"
OPENWEBUI_BACKUP="${BACKUP_PREFIX}_openwebui.tar.gz"

if [ ! -f "$DB_BACKUP" ]; then
    warn "Database backup not found: $DB_BACKUP"
fi

if [ ! -f "$CONFIG_BACKUP" ]; then
    warn "Config backup not found: $CONFIG_BACKUP"
fi

echo ""

# ============================================================================
# Stop Services
# ============================================================================

info "Stopping DataAICore services..."
./scripts/orionctl down 2>/dev/null || warn "Failed to stop services"
success "Services stopped"
echo ""

# ============================================================================
# Restore Database
# ============================================================================

if [ -f "$DB_BACKUP" ]; then
    info "Restoring Nextcloud database..."
    
    # Start only PostgreSQL
    docker compose --profile nextcloud up -d postgres
    
    # Wait for PostgreSQL to be ready
    info "Waiting for PostgreSQL to be ready..."
    for _ in {1..30}; do
        if docker exec orion_dataaicore_postgres pg_isready -U "$POSTGRES_USER" > /dev/null 2>&1; then
            success "PostgreSQL is ready"
            break
        fi
        sleep 2
    done
    
    # Drop and recreate database
    POSTGRES_USER="${POSTGRES_USER:-nextcloud}"
    POSTGRES_DB="${POSTGRES_DB:-nextcloud}"
    
    docker exec orion_dataaicore_postgres psql -U "$POSTGRES_USER" -c "DROP DATABASE IF EXISTS $POSTGRES_DB;" postgres || true
    docker exec orion_dataaicore_postgres psql -U "$POSTGRES_USER" -c "CREATE DATABASE $POSTGRES_DB;" postgres
    
    # Restore database
    gunzip -c "$DB_BACKUP" | docker exec -i orion_dataaicore_postgres psql -U "$POSTGRES_USER" "$POSTGRES_DB"
    
    success "Database restored"
    
    # Stop PostgreSQL
    docker stop orion_dataaicore_postgres
else
    warn "Skipping database restore - backup not found"
fi

echo ""

# ============================================================================
# Restore Configuration
# ============================================================================

if [ -f "$CONFIG_BACKUP" ]; then
    info "Restoring configuration files..."
    
    tar -xzf "$CONFIG_BACKUP" -C "$REPO_ROOT"
    
    success "Configuration restored"
else
    warn "Skipping config restore - backup not found"
fi

echo ""

# ============================================================================
# Restore Open WebUI Data
# ============================================================================

if [ -f "$OPENWEBUI_BACKUP" ]; then
    info "Restoring Open WebUI data..."
    
    sudo tar -xzf "$OPENWEBUI_BACKUP" -C /
    
    success "Open WebUI data restored"
else
    warn "Skipping Open WebUI restore - backup not found"
fi

echo ""

# ============================================================================
# Restore Nextcloud App/Data (Manual)
# ============================================================================

info "Nextcloud app/data restore (manual)..."
warn "To restore Nextcloud app/data, run manually:"
echo "  sudo tar -xzf ${BACKUP_PREFIX}_nextcloud_app.tar.gz -C /"
echo "  sudo tar -xzf ${BACKUP_PREFIX}_nextcloud_data.tar.gz -C /"
echo "  sudo chown -R www-data:www-data $DATA_ROOT/nextcloud/app"
echo "  sudo chown -R www-data:www-data $DATA_ROOT/nextcloud/data"
echo ""

# ============================================================================
# Summary
# ============================================================================

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                  Restore Complete!                             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

success "Data restored from backup"
echo ""

info "Next steps:"
echo "  1. Review .env settings:"
echo "     sudo nano .env"
echo ""
echo "  2. Start services:"
echo "     ./scripts/orionctl up core"
echo ""
echo "  3. Verify services are working:"
echo "     ./scripts/orionctl doctor"
echo ""
