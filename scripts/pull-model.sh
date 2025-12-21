#!/usr/bin/env bash
# ============================================================================
# Orion-Sentinel-DataAICore - Ollama Model Pull Helper
# Downloads and manages LLM models for Ollama
#
# Usage:
#   ./scripts/pull-model.sh <model>
#   ./scripts/pull-model.sh llama3.2:3b
#   ./scripts/pull-model.sh qwen2.5:3b
#   ./scripts/pull-model.sh --list
#
# ============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Container name
OLLAMA_CONTAINER="orion_dataaicore_ollama"

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

# Usage
usage() {
    cat << EOF
${CYAN}Ollama Model Pull Helper${NC}

${YELLOW}Usage:${NC}
  $0 <model>        Pull a model
  $0 --list         List installed models
  $0 --help         Show this help

${YELLOW}Recommended Models (CPU-friendly):${NC}
  llama3.2:3b       Meta's Llama 3.2 (3B params, ~2GB)
  qwen2.5:3b        Alibaba's Qwen 2.5 (3B params, ~2GB)
  phi3:mini         Microsoft's Phi-3 Mini (~2GB)
  gemma:2b          Google's Gemma (2B params, ~1.5GB)

${YELLOW}Larger Models (require more RAM):${NC}
  llama3.2:7b       Meta's Llama 3.2 (7B params, ~4GB)
  mistral:7b        Mistral AI (7B params, ~4GB)
  llama3.2:13b      Meta's Llama 3.2 (13B params, ~8GB)

${YELLOW}Examples:${NC}
  $0 llama3.2:3b
  $0 qwen2.5:3b
  $0 --list

${YELLOW}Notes:${NC}
  - Ollama container must be running
  - Models are stored in \${DATA_ROOT}/llm/ollama
  - Download time depends on network speed (2-8GB per model)
  - First model pull may take several minutes

EOF
}

# Check Ollama is running
check_ollama() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${OLLAMA_CONTAINER}$"; then
        error "Ollama container is not running. Start with: ./scripts/orionctl up llm"
    fi
}

# List installed models
list_models() {
    check_ollama
    
    info "Installed models:"
    echo ""
    docker exec "$OLLAMA_CONTAINER" ollama list
    echo ""
}

# Pull a model
pull_model() {
    local model="$1"
    
    check_ollama
    
    info "Pulling model: $model"
    warn "This may take several minutes depending on your network speed..."
    echo ""
    
    docker exec -it "$OLLAMA_CONTAINER" ollama pull "$model"
    
    echo ""
    success "Model '$model' pulled successfully!"
    echo ""
    info "You can now use this model in Open WebUI at http://<HOST_IP>:3000"
    echo ""
}

# Main
if [ $# -eq 0 ]; then
    usage
    exit 1
fi

case "$1" in
    --list|-l)
        list_models
        ;;
    --help|-h)
        usage
        ;;
    *)
        pull_model "$1"
        ;;
esac
