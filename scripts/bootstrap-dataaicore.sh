#!/usr/bin/env bash
# ============================================================================
# Orion-Sentinel-DataAICore Bootstrap Script
# Creates directories, generates secrets, and initializes configuration
#
# This script is idempotent - safe to run multiple times.
#
# Usage:
#   ./scripts/bootstrap-dataaicore.sh
#
# ============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$REPO_ROOT"

# ============================================================================
# Helper Functions
# ============================================================================

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

# Generate random password (32 chars, alphanumeric)
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

# Generate random secret (64 hex chars)
generate_secret() {
    openssl rand -hex 32
}

# Create directory if it doesn't exist
ensure_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        info "Creating directory: $dir"
        sudo mkdir -p "$dir"
        sudo chown -R "$USER:$USER" "$dir"
        success "Created: $dir"
    else
        info "Directory exists: $dir"
    fi
}

# ============================================================================
# Banner
# ============================================================================

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║       Orion-Sentinel-DataAICore Bootstrap                     ║"
echo "║       Dell OptiPlex 7080 - Cloud, Search, AI Stack            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# ============================================================================
# Pre-flight Checks
# ============================================================================

# Check not running as root
if [ "$EUID" -eq 0 ]; then
    error "Do not run this script as root. It will use sudo when needed."
fi

# Check for Docker
if ! command -v docker &> /dev/null; then
    warn "Docker not found!"
    echo ""
    echo "Install Docker with:"
    echo "  curl -fsSL https://get.docker.com -o get-docker.sh"
    echo "  sudo sh get-docker.sh"
    echo "  sudo usermod -aG docker \$USER"
    echo ""
    echo "Then log out and back in, and run this script again."
    error "Docker is required"
fi

# Check for Docker Compose
if ! docker compose version &> /dev/null; then
    error "Docker Compose v2 not found. Please install Docker Compose v2.20+"
fi

# Check Docker Compose version
COMPOSE_VERSION=$(docker compose version --short 2>/dev/null || echo "0.0.0")
info "Docker Compose version: $COMPOSE_VERSION"

# Check user is in docker group
if ! groups | grep -q docker; then
    warn "User is not in 'docker' group."
    echo "  Run: sudo usermod -aG docker \$USER"
    echo "  Then log out and back in."
    error "Docker group membership required"
fi

success "Pre-flight checks passed"
echo ""

# ============================================================================
# Configuration
# ============================================================================

# Default data root
DATA_ROOT="${DATA_ROOT:-/srv/orion/dataaicore}"
info "Data root: $DATA_ROOT"
echo ""

# ============================================================================
# Create Directory Structure
# ============================================================================

info "Creating directory structure..."

# Main directories
ensure_dir "$DATA_ROOT"
ensure_dir "$DATA_ROOT/secrets"

# Nextcloud
ensure_dir "$DATA_ROOT/nextcloud/app"
ensure_dir "$DATA_ROOT/nextcloud/data"
ensure_dir "$DATA_ROOT/nextcloud/postgres"

# Redis
ensure_dir "$DATA_ROOT/redis"

# SearXNG
ensure_dir "$DATA_ROOT/searxng"

# LLM
ensure_dir "$DATA_ROOT/llm/ollama"
ensure_dir "$DATA_ROOT/llm/openwebui"

# Caddy (for public-nextcloud)
ensure_dir "$DATA_ROOT/caddy/data"
ensure_dir "$DATA_ROOT/caddy/config"

echo ""
success "Directory structure created"
echo ""

# ============================================================================
# Create Docker Networks
# ============================================================================

info "Creating Docker networks..."

# Internal network
if docker network inspect dataaicore_internal &> /dev/null; then
    info "Network dataaicore_internal already exists"
else
    docker network create dataaicore_internal
    success "Network dataaicore_internal created"
fi

# LAN network
if docker network inspect dataaicore_lan &> /dev/null; then
    info "Network dataaicore_lan already exists"
else
    docker network create dataaicore_lan
    success "Network dataaicore_lan created"
fi

echo ""

# ============================================================================
# Generate .env File
# ============================================================================

ENV_FILE="$REPO_ROOT/.env"
ENV_EXAMPLE="$REPO_ROOT/env/.env.example"

if [ -f "$ENV_FILE" ]; then
    warn ".env file already exists - not overwriting"
    info "To regenerate, delete .env and run this script again"
else
    info "Generating .env file with secure secrets..."

    # Generate secrets
    NEXTCLOUD_ADMIN_PASSWORD=$(generate_password)
    POSTGRES_PASSWORD=$(generate_password)
    REDIS_PASSWORD=$(generate_password)
    SEARXNG_SECRET_KEY=$(generate_secret)
    WEBUI_SECRET_KEY=$(generate_secret)

    # Copy example
    cp "$ENV_EXAMPLE" "$ENV_FILE"

    # Replace placeholders with generated secrets
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS sed
        sed -i '' "s/NEXTCLOUD_ADMIN_PASSWORD=CHANGE_ME_GENERATED_BY_BOOTSTRAP/NEXTCLOUD_ADMIN_PASSWORD=$NEXTCLOUD_ADMIN_PASSWORD/" "$ENV_FILE"
        sed -i '' "s/POSTGRES_PASSWORD=CHANGE_ME_GENERATED_BY_BOOTSTRAP/POSTGRES_PASSWORD=$POSTGRES_PASSWORD/" "$ENV_FILE"
        sed -i '' "s/REDIS_PASSWORD=CHANGE_ME_GENERATED_BY_BOOTSTRAP/REDIS_PASSWORD=$REDIS_PASSWORD/" "$ENV_FILE"
        sed -i '' "s/SEARXNG_SECRET_KEY=CHANGE_ME_GENERATED_BY_BOOTSTRAP/SEARXNG_SECRET_KEY=$SEARXNG_SECRET_KEY/" "$ENV_FILE"
        sed -i '' "s/WEBUI_SECRET_KEY=CHANGE_ME_GENERATED_BY_BOOTSTRAP/WEBUI_SECRET_KEY=$WEBUI_SECRET_KEY/" "$ENV_FILE"
    else
        # Linux sed
        sed -i "s/NEXTCLOUD_ADMIN_PASSWORD=CHANGE_ME_GENERATED_BY_BOOTSTRAP/NEXTCLOUD_ADMIN_PASSWORD=$NEXTCLOUD_ADMIN_PASSWORD/" "$ENV_FILE"
        sed -i "s/POSTGRES_PASSWORD=CHANGE_ME_GENERATED_BY_BOOTSTRAP/POSTGRES_PASSWORD=$POSTGRES_PASSWORD/" "$ENV_FILE"
        sed -i "s/REDIS_PASSWORD=CHANGE_ME_GENERATED_BY_BOOTSTRAP/REDIS_PASSWORD=$REDIS_PASSWORD/" "$ENV_FILE"
        sed -i "s/SEARXNG_SECRET_KEY=CHANGE_ME_GENERATED_BY_BOOTSTRAP/SEARXNG_SECRET_KEY=$SEARXNG_SECRET_KEY/" "$ENV_FILE"
        sed -i "s/WEBUI_SECRET_KEY=CHANGE_ME_GENERATED_BY_BOOTSTRAP/WEBUI_SECRET_KEY=$WEBUI_SECRET_KEY/" "$ENV_FILE"
    fi

    # Detect HOST_IP
    HOST_IP=$(hostname -I | awk '{print $1}')
    if [ -n "$HOST_IP" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/HOST_IP=0.0.0.0/HOST_IP=$HOST_IP/" "$ENV_FILE"
            sed -i '' "s/NEXTCLOUD_TRUSTED_DOMAINS=localhost/NEXTCLOUD_TRUSTED_DOMAINS=localhost $HOST_IP/" "$ENV_FILE"
        else
            sed -i "s/HOST_IP=0.0.0.0/HOST_IP=$HOST_IP/" "$ENV_FILE"
            sed -i "s/NEXTCLOUD_TRUSTED_DOMAINS=localhost/NEXTCLOUD_TRUSTED_DOMAINS=localhost $HOST_IP/" "$ENV_FILE"
        fi
        info "Detected HOST_IP: $HOST_IP"
    fi

    # Set secure permissions
    chmod 600 "$ENV_FILE"

    success ".env file created with generated secrets"
    info "Review and customize: sudo nano .env"
fi
echo ""

# ============================================================================
# Summary
# ============================================================================

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    Bootstrap Complete!                         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
success "DataAICore is ready to deploy!"
echo ""
info "Next steps:"
echo ""
echo "  1. Review configuration:"
echo "     sudo nano .env"
echo ""
echo "  2. Start the core bundle (Nextcloud + SearXNG + LLM):"
echo "     ./scripts/orionctl up core"
echo ""
echo "  3. Pull an LLM model:"
echo "     ./scripts/pull-model.sh llama3.2:3b"
echo ""
echo "  4. Access services:"
echo "     • Nextcloud:   http://${HOST_IP:-<HOST_IP>}:8080"
echo "     • SearXNG:     http://${HOST_IP:-<HOST_IP>}:8888"
echo "     • Open WebUI:  http://${HOST_IP:-<HOST_IP>}:3000"
echo ""
info "For complete installation guide, see INSTALL.md"
echo ""
