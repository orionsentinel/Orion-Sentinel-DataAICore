# Orion-Sentinel-DataAICore

**Data, cloud, and AI services stack for Dell OptiPlex 7080 Micro**

## Overview

Orion-Sentinel-DataAICore is a production-ready, self-hosted stack for cloud storage, web search, and local AI. Designed for Dell OptiPlex 7080 Micro (i5-10500T, 16GB RAM, 512GB SSD) running Ubuntu Server, it provides:

- **Nextcloud** - Self-hosted file sync and collaboration
- **SearXNG** - Privacy-focused meta-search engine (web search)
- **Ollama + Open WebUI** - Local LLM inference with ChatGPT-like interface

**Default Security Posture:** All services are **LOCAL ONLY** (LAN access). No public exposure by default.

**Optional Phase 2:** Enable public access for **ONLY Nextcloud** via a dedicated reverse proxy profile.

## What Runs Here

| Profile | Services | Description |
|---------|----------|-------------|
| `nextcloud` | Nextcloud + Postgres + Redis | Self-hosted cloud storage |
| `websearch` | SearXNG | Privacy-focused web meta-search |
| `llm` | Ollama + Open WebUI | Local AI assistant |
| `public-nextcloud` | Caddy reverse proxy | Optional: Public Nextcloud access |

### Important: Phase 1 Scope

This is a **Phase 1** deployment focused on stability:
- ❌ No local document indexing (no Meilisearch/Tika)
- ❌ No SearXNG rate limiter (no Valkey/Redis for search)
- ✅ Web search via SearXNG works out of the box
- ✅ LLM chat via Open WebUI works out of the box
- ✅ All services LOCAL ONLY by default

## Hardware Requirements

**Target Hardware:** Dell OptiPlex 7080 Micro
- **CPU:** Intel i5-10500T (6 cores, 12 threads)
- **RAM:** 16GB minimum, 32GB recommended for larger LLMs
- **Storage:** 512GB SSD minimum
- **Network:** Gigabit Ethernet

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/orionsentinel/Orion-Sentinel-DataAICore.git
cd Orion-Sentinel-DataAICore

# 2. Run bootstrap (creates directories, generates secrets)
./scripts/bootstrap-dataaicore.sh

# 3. Review configuration
sudo nano .env

# 4. Start the core bundle (nextcloud + websearch + llm)
./scripts/orionctl up core

# 5. Pull a small LLM model
./scripts/pull-model.sh llama3.2:3b
```

## Access Points (LAN Only)

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| Nextcloud | `http://<HOST_IP>:8080` | admin / (see .env) |
| SearXNG | `http://<HOST_IP>:8888` | None required |
| Open WebUI | `http://<HOST_IP>:3000` | Create on first visit |

## Storage Layout

All data is stored under `${DATA_ROOT}` (default: `/srv/orion/dataaicore`):

```
/srv/orion/dataaicore/
├── nextcloud/
│   ├── app/           # Nextcloud application files
│   ├── data/          # User files (can be large!)
│   └── postgres/      # Database
├── redis/             # Nextcloud file locking cache
├── searxng/           # SearXNG configuration
└── llm/
    ├── ollama/        # LLM models (can be large!)
    └── openwebui/     # Open WebUI data
```

## Management Commands

```bash
# Start services
./scripts/orionctl up nextcloud      # Nextcloud only
./scripts/orionctl up websearch      # SearXNG only
./scripts/orionctl up llm            # Ollama + Open WebUI
./scripts/orionctl up core           # All of the above

# Stop services
./scripts/orionctl down              # Stop all
./scripts/orionctl down nextcloud    # Stop specific stack

# View status and logs
./scripts/orionctl ps                # Show running containers
./scripts/orionctl logs nextcloud    # View logs
./scripts/orionctl doctor            # Health check

# Update images
./scripts/orionctl update            # Pull and restart
```

## Profiles

Enable services using Docker Compose profiles:

| Profile | Services | Use Case |
|---------|----------|----------|
| `nextcloud` | Nextcloud + Postgres + Redis | Self-hosted cloud |
| `websearch` | SearXNG | Privacy web search |
| `llm` | Ollama + Open WebUI | Local AI assistant |
| `public-nextcloud` | Caddy reverse proxy | **Optional:** Public Nextcloud |

**Bundle shortcuts:**
- `core` = nextcloud + websearch + llm

## LLM Usage

After starting the LLM stack, pull a model:

```bash
# Small models (CPU-friendly, recommended)
./scripts/pull-model.sh llama3.2:3b
./scripts/pull-model.sh qwen2.5:3b

# Larger models (if you have 32GB+ RAM)
./scripts/pull-model.sh llama3.2:7b
```

**Model sizes:**
- 3B parameters: ~2GB download, fast on CPU
- 7B parameters: ~4GB download, slower on CPU

## Security

- All services run on **LAN ONLY** by default
- No public exposure except when `public-nextcloud` profile is explicitly enabled
- See [SECURITY.md](SECURITY.md) for detailed security guidelines

## Documentation

- [INSTALL.md](INSTALL.md) - Complete installation guide
- [CONFIGURATION.md](CONFIGURATION.md) - Environment variables
- [OPERATIONS.md](OPERATIONS.md) - Day-to-day operations
- [SECURITY.md](SECURITY.md) - Security guidelines
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Problem solving

## Network Configuration

By default, all services use the `dataaicore_internal` Docker network.

**Published to LAN:**
- Nextcloud: `${HOST_IP}:8080`
- SearXNG: `${HOST_IP}:8888`
- Open WebUI: `${HOST_IP}:3000`

**Internal only (NOT published):**
- Postgres
- Redis
- Ollama API (accessed by Open WebUI internally)

## Timezone

Default timezone is `Europe/Amsterdam`. Change in `.env`:

```bash
TZ=America/New_York  # or your timezone
```

## License

MIT License - See [LICENSE](LICENSE)

---

**Hardware:** Dell OptiPlex 7080 Micro (x86-64)
**Purpose:** Cloud storage, web search, local AI
**Security:** Local-only by default, optional public Nextcloud only