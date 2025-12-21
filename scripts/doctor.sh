#!/usr/bin/env bash
# ============================================================================
# Orion-Sentinel-DataAICore Doctor Script
# Health checks for the DataAICore stack
#
# Usage:
#   ./scripts/doctor.sh
#
# This script can also be invoked via orionctl:
#   ./scripts/orionctl doctor
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

fail() {
    echo -e "${RED}✗${NC} $*"
}

# Load environment
if [ -f ".env" ]; then
    source .env 2>/dev/null || true
fi

DATA_ROOT="${DATA_ROOT:-/srv/orion/dataaicore}"
HOST_IP="${HOST_IP:-localhost}"

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║               DataAICore Health Check                          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

STATUS=0

# ============================================================================
# System Checks
# ============================================================================

echo "=== System Checks ==="
echo ""

# Docker daemon
info "Docker daemon..."
if docker info &>/dev/null; then
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | tr -d ',')
    success "Running (v$DOCKER_VERSION)"
else
    fail "Not running or not accessible"
    STATUS=1
fi

# Docker Compose
info "Docker Compose..."
if docker compose version &>/dev/null; then
    COMPOSE_VERSION=$(docker compose version --short)
    success "Installed (v$COMPOSE_VERSION)"
else
    fail "Not found"
    STATUS=1
fi

# User in docker group
info "Docker group membership..."
if groups | grep -q docker; then
    success "User is in docker group"
else
    warn "User is not in docker group"
fi

# .env file
info ".env file..."
if [ -f ".env" ]; then
    success "Exists"
else
    fail "Missing - run bootstrap first"
    STATUS=1
fi

# Memory info
info "Memory..."
if command -v free &>/dev/null; then
    TOTAL_MEM=$(free -h | awk '/^Mem:/ {print $2}')
    AVAIL_MEM=$(free -h | awk '/^Mem:/ {print $7}')
    success "Total: $TOTAL_MEM, Available: $AVAIL_MEM"
else
    warn "free command not available"
fi

echo ""

# ============================================================================
# Storage Checks
# ============================================================================

echo "=== Storage Checks ==="
echo ""

# Data root
info "Data root ($DATA_ROOT)..."
if [ -d "$DATA_ROOT" ]; then
    success "Exists"
else
    fail "Does not exist"
    STATUS=1
fi

# Writable
info "Data directory writable..."
if [ -w "$DATA_ROOT" ]; then
    success "Writable"
else
    fail "Not writable"
    STATUS=1
fi

# Disk space
info "Disk space..."
if command -v df &>/dev/null; then
    FREE_SPACE=$(df -BG "$DATA_ROOT" 2>/dev/null | tail -1 | awk '{print $4}' | tr -d 'G')
    USED_PERCENT=$(df "$DATA_ROOT" 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
    
    if [ -n "$FREE_SPACE" ]; then
        if [ "$FREE_SPACE" -gt 20 ]; then
            success "${FREE_SPACE}GB free (${USED_PERCENT}% used)"
        elif [ "$FREE_SPACE" -gt 5 ]; then
            warn "${FREE_SPACE}GB free (${USED_PERCENT}% used) - consider cleanup"
        else
            fail "${FREE_SPACE}GB free (${USED_PERCENT}% used) - critically low!"
            STATUS=1
        fi
    fi
fi

echo ""

# ============================================================================
# Network Checks
# ============================================================================

echo "=== Network Checks ==="
echo ""

# Docker network
info "Docker network (dataaicore_internal)..."
if docker network inspect dataaicore_internal &>/dev/null; then
    success "Exists"
else
    warn "Does not exist - will be created on first up"
fi

info "Docker network (dataaicore_lan)..."
if docker network inspect dataaicore_lan &>/dev/null; then
    success "Exists"
else
    warn "Does not exist - will be created on first up"
fi

# Port availability/usage
info "Port 8080 (Nextcloud)..."
if ss -lntp 2>/dev/null | grep -q ":8080 "; then
    success "In use (service running)"
else
    info "Available (service not running)"
fi

info "Port 8888 (SearXNG)..."
if ss -lntp 2>/dev/null | grep -q ":8888 "; then
    success "In use (service running)"
else
    info "Available (service not running)"
fi

info "Port 3000 (Open WebUI)..."
if ss -lntp 2>/dev/null | grep -q ":3000 "; then
    success "In use (service running)"
else
    info "Available (service not running)"
fi

# Check for port conflicts
info "Checking for port conflicts..."
CONFLICTS=0
for port in 8080 8888 3000; do
    COUNT=$(ss -lntp 2>/dev/null | grep -c ":$port " || true)
    if [ "$COUNT" -gt 1 ]; then
        warn "Port $port has multiple listeners!"
        CONFLICTS=1
    fi
done
if [ $CONFLICTS -eq 0 ]; then
    success "No port conflicts detected"
fi

echo ""

# ============================================================================
# Service Checks
# ============================================================================

echo "=== Service Checks ==="
echo ""

# Check each container
check_container() {
    local name="$1"
    local display="$2"
    local health
    
    info "$display..."
    if docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
        health=$(docker inspect --format='{{.State.Health.Status}}' "$name" 2>/dev/null || echo "none")
        case "$health" in
            healthy)
                success "Running (healthy)"
                ;;
            unhealthy)
                fail "Running (unhealthy)"
                STATUS=1
                ;;
            starting)
                warn "Running (starting)"
                ;;
            *)
                success "Running"
                ;;
        esac
    else
        info "Not running"
    fi
}

check_container "orion_dataaicore_postgres" "PostgreSQL"
check_container "orion_dataaicore_redis" "Redis"
check_container "orion_dataaicore_nextcloud" "Nextcloud"
check_container "orion_dataaicore_nextcloud_cron" "Nextcloud Cron"
check_container "orion_dataaicore_searxng" "SearXNG"
check_container "orion_dataaicore_ollama" "Ollama"
check_container "orion_dataaicore_openwebui" "Open WebUI"
check_container "orion_dataaicore_caddy" "Caddy"

echo ""

# ============================================================================
# Connectivity Checks (if services are running)
# ============================================================================

echo "=== Connectivity Checks ==="
echo ""

# Nextcloud
if docker ps --format '{{.Names}}' | grep -q "orion_dataaicore_nextcloud"; then
    info "Nextcloud HTTP..."
    if curl -sf -o /dev/null "http://localhost:8080/status.php" 2>/dev/null; then
        success "Responding"
    else
        warn "Not responding (may still be starting)"
    fi
fi

# SearXNG
if docker ps --format '{{.Names}}' | grep -q "orion_dataaicore_searxng"; then
    info "SearXNG HTTP..."
    if curl -sf -o /dev/null "http://localhost:8888/healthz" 2>/dev/null; then
        success "Responding"
    else
        warn "Not responding (may still be starting)"
    fi
fi

# Open WebUI
if docker ps --format '{{.Names}}' | grep -q "orion_dataaicore_openwebui"; then
    info "Open WebUI HTTP..."
    if curl -sf -o /dev/null "http://localhost:3000/health" 2>/dev/null; then
        success "Responding"
    else
        warn "Not responding (may still be starting)"
    fi
fi

# Ollama API
if docker ps --format '{{.Names}}' | grep -q "orion_dataaicore_ollama"; then
    info "Ollama API..."
    # Check via Open WebUI container to verify internal connectivity
    if docker exec orion_dataaicore_ollama curl -sf "http://localhost:11434/api/tags" &>/dev/null; then
        success "Responding"
        # List models
        MODELS=$(docker exec orion_dataaicore_ollama ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | tr '\n' ' ')
        if [ -n "$MODELS" ]; then
            info "Models: $MODELS"
        else
            info "No models installed"
        fi
    else
        warn "Not responding (may still be starting)"
    fi
fi

echo ""

# ============================================================================
# Summary
# ============================================================================

echo "╔════════════════════════════════════════════════════════════════╗"
if [ $STATUS -eq 0 ]; then
    echo "║               ${GREEN}All checks passed!${NC}                             ║"
else
    echo "║               ${YELLOW}Some checks need attention${NC}                      ║"
fi
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

if [ $STATUS -ne 0 ]; then
    echo -e "${YELLOW}Next steps:${NC}"
    echo ""
    
    # Actionable recommendations
    if [ ! -f ".env" ]; then
        echo "  1. Run bootstrap to create .env:"
        echo "     ./scripts/bootstrap-dataaicore.sh"
        echo ""
    fi
    
    if ! docker ps -q 2>/dev/null | grep -q .; then
        echo "  2. Start services:"
        echo "     ./scripts/orionctl up core"
        echo ""
    fi
    
    echo "  3. Check logs for errors:"
    echo "     ./scripts/orionctl logs"
    echo ""
fi

exit $STATUS
