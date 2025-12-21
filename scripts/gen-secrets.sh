#!/usr/bin/env bash
# ============================================================================
# Orion-Sentinel-DataAICore Secret Generation Script
# Generates secure random secrets for use in .env file
#
# Usage:
#   ./scripts/gen-secrets.sh
#
# This script generates strong random secrets using openssl.
# Secrets are printed to stdout - store them securely.
#
# ============================================================================

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ============================================================================
# Secret Generation Functions
# ============================================================================

# Generate random password (32 chars, alphanumeric + special)
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

# Generate random secret (64 hex chars)
generate_secret() {
    openssl rand -hex 32
}

# ============================================================================
# Main
# ============================================================================

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       Orion-Sentinel-DataAICore Secret Generator              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}Generating secure random secrets...${NC}"
echo ""

echo "# ============================================================================"
echo "# Generated Secrets - $(date)"
echo "# Copy these values to your .env file"
echo "# ============================================================================"
echo ""

echo "# Nextcloud Admin Password"
echo "NEXTCLOUD_ADMIN_PASSWORD=$(generate_password)"
echo ""

echo "# PostgreSQL Database Password"
echo "POSTGRES_PASSWORD=$(generate_password)"
echo ""

echo "# Redis Cache Password"
echo "REDIS_PASSWORD=$(generate_password)"
echo ""

echo "# SearXNG Secret Key (for secure cookies)"
echo "SEARXNG_SECRET_KEY=$(generate_secret)"
echo ""

echo "# Open WebUI Secret Key (for session encryption)"
echo "WEBUI_SECRET_KEY=$(generate_secret)"
echo ""

echo "# ============================================================================"
echo ""
echo -e "${GREEN}✓ Secrets generated successfully!${NC}"
echo ""
echo -e "${YELLOW}Usage:${NC}"
echo "  1. Copy the values above to your .env file:"
echo "     sudo nano .env"
echo ""
echo "  2. Replace the CHANGE_ME placeholders with generated values"
echo ""
echo "  3. Secure your .env file:"
echo "     chmod 600 .env"
echo ""
echo -e "${YELLOW}Security:${NC}"
echo "  • Store secrets securely (password manager recommended)"
echo "  • Never commit .env to version control"
echo "  • Rotate secrets periodically (annually recommended)"
echo ""
