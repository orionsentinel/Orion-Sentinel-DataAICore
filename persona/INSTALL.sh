#!/usr/bin/env bash
# Persona — Sovereign AI Identity Infrastructure
# One-command installer for macOS and Linux
#
# Usage: curl -sSL https://raw.githubusercontent.com/.../INSTALL.sh | bash
#    or: ./INSTALL.sh
#
# This script is idempotent — safe to run multiple times.
# USER/ profile files are NEVER overwritten on re-install.

set -euo pipefail

# ── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${BLUE}▶${RESET} $*"; }
success() { echo -e "${GREEN}✓${RESET} $*"; }
warn()    { echo -e "${YELLOW}⚠${RESET} $*"; }
error()   { echo -e "${RED}✗${RESET} $*" >&2; }
heading() { echo -e "\n${BOLD}$*${RESET}"; }

# ── Constants ─────────────────────────────────────────────────────────────────
PERSONA_DIR="${PERSONA_DIR:-$HOME/.persona}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIN_PYTHON_MINOR=11

# ── OS detection ──────────────────────────────────────────────────────────────
detect_os() {
    case "$(uname -s)" in
        Darwin) echo "macos" ;;
        Linux)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                echo "wsl"
            else
                echo "linux"
            fi
            ;;
        *)
            error "Unsupported operating system: $(uname -s)"
            exit 1
            ;;
    esac
}

OS=$(detect_os)
info "Detected OS: ${OS}"

# ── Python check ──────────────────────────────────────────────────────────────
heading "Checking Python version..."

PYTHON_BIN=""
for candidate in python3.13 python3.12 python3.11 python3; do
    if command -v "$candidate" &>/dev/null; then
        version=$("$candidate" -c 'import sys; print(sys.version_info.minor)')
        major=$("$candidate" -c 'import sys; print(sys.version_info.major)')
        if [[ "$major" -eq 3 && "$version" -ge "$MIN_PYTHON_MINOR" ]]; then
            PYTHON_BIN="$candidate"
            break
        fi
    fi
done

if [[ -z "$PYTHON_BIN" ]]; then
    error "Python 3.${MIN_PYTHON_MINOR}+ is required but was not found."
    echo ""
    echo "Install Python 3.11 or later:"
    case "$OS" in
        macos)
            echo "  brew install python@3.12"
            echo "  or download from: https://www.python.org/downloads/"
            ;;
        linux|wsl)
            echo "  sudo apt update && sudo apt install python3.12 python3.12-venv"
            echo "  or: sudo dnf install python3.12"
            echo "  or download from: https://www.python.org/downloads/"
            ;;
    esac
    exit 1
fi

success "Found $($PYTHON_BIN --version)"

# ── uv check/install ──────────────────────────────────────────────────────────
heading "Checking uv package manager..."

if ! command -v uv &>/dev/null; then
    info "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # Add uv to PATH for this session
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    if ! command -v uv &>/dev/null; then
        error "uv installation failed. Please install manually: https://docs.astral.sh/uv/"
        exit 1
    fi
fi

success "Found uv $(uv --version)"

# ── Install Persona ───────────────────────────────────────────────────────────
heading "Installing Persona..."

cd "$REPO_DIR"
uv tool install . --python "$PYTHON_BIN" 2>&1 | grep -v "^$" || true

# Verify installation
if ! command -v persona &>/dev/null; then
    # Try adding uv tool bin to PATH
    UV_TOOL_BIN="$(uv tool dir)/bin"
    if [[ -d "$UV_TOOL_BIN" ]]; then
        export PATH="$UV_TOOL_BIN:$PATH"
    fi
fi

if command -v persona &>/dev/null; then
    success "persona CLI installed: $(persona --help | head -1)"
else
    warn "persona command not found in PATH after install."
    warn "You may need to add uv's tool bin directory to your PATH."
fi

# ── Create persona directory structure ────────────────────────────────────────
heading "Setting up ~/.persona directory..."

mkdir -p "$PERSONA_DIR"/{USER,config,logs}
success "Created $PERSONA_DIR"

# ── Copy config files (safe to overwrite — these are not user data) ───────────
if [[ -f "$REPO_DIR/config/persona.yaml" ]]; then
    cp "$REPO_DIR/config/persona.yaml" "$PERSONA_DIR/config/persona.yaml"
    success "Copied config/persona.yaml"
fi

if [[ -f "$REPO_DIR/config/allowlist.yaml" ]]; then
    cp "$REPO_DIR/config/allowlist.yaml" "$PERSONA_DIR/config/allowlist.yaml"
    success "Copied config/allowlist.yaml"
fi

# ── Create USER/ template files — NEVER overwrite existing files ──────────────
heading "Creating USER/ profile templates..."

USER_DIR="$PERSONA_DIR/USER"

copy_template() {
    local filename="$1"
    local dest="$USER_DIR/$filename"
    local src="$REPO_DIR/USER/$filename"

    if [[ -f "$dest" ]]; then
        warn "Skipping $filename — already exists (preserving your data)"
    else
        if [[ -f "$src" ]]; then
            cp "$src" "$dest"
            success "Created $filename"
        else
            warn "Template $filename not found in source — skipping"
        fi
    fi
}

PROFILE_FILES=(
    ".ring"
    "identity.md"
    "skills.md"
    "history.md"
    "communication.md"
    "current-focus.md"
    "goals.md"
    "relationships.md"
    "preferences.md"
    "constraints.md"
    "private.md"
)

for f in "${PROFILE_FILES[@]}"; do
    copy_template "$f"
done

# ── Shell alias ───────────────────────────────────────────────────────────────
heading "Configuring shell..."

add_to_shell() {
    local rc_file="$1"
    local line='export PATH="$HOME/.local/bin:$PATH"'

    if [[ -f "$rc_file" ]]; then
        if grep -qF '.local/bin' "$rc_file"; then
            warn "PATH already configured in $rc_file — skipping"
        else
            echo "" >> "$rc_file"
            echo "# Added by Persona installer" >> "$rc_file"
            echo "$line" >> "$rc_file"
            success "Added PATH to $rc_file"
        fi
    fi
}

case "$SHELL" in
    */zsh)  add_to_shell "$HOME/.zshrc" ;;
    */bash) add_to_shell "$HOME/.bashrc" ;;
    *)
        warn "Unknown shell: $SHELL"
        warn "Manually add: export PATH=\"\$HOME/.local/bin:\$PATH\""
        ;;
esac

# ── Done ──────────────────────────────────────────────────────────────────────
heading "Installation complete!"
echo ""
echo -e "${GREEN}${BOLD}Persona is installed.${RESET} Here's what to do next:"
echo ""
echo -e "  ${BOLD}1. Build your profile${RESET}"
echo "     Open prompts/onboarding.md and paste the prompt into any AI assistant."
echo "     It will guide you through creating your Persona profile."
echo "     Save the output files to: $USER_DIR/"
echo ""
echo -e "  ${BOLD}2. Validate your profile${RESET}"
echo "     Run: ${BLUE}persona validate${RESET}"
echo "     This checks all your profile files are correctly formatted."
echo ""
echo -e "  ${BOLD}3. Start the MCP server${RESET}"
echo "     Run: ${BLUE}persona serve${RESET}"
echo "     Then connect your AI tool using the guide in:"
echo "     docs/integrations/claude-desktop.md"
echo ""
echo -e "  ${BOLD}Your profile lives at:${RESET} $USER_DIR"
echo -e "  ${BOLD}Server config:${RESET} $PERSONA_DIR/config/persona.yaml"
echo ""
echo "Need help? Open README.md or visit the project repository."
echo ""
