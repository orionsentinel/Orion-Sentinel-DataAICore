# Orion-Sentinel-DataAICore Installation Guide

Complete step-by-step installation guide for Dell OptiPlex 7080 Micro or similar x86-64 hardware.

## Prerequisites

### Hardware
- **Target:** Dell OptiPlex 7080 Micro (or similar x86-64 PC)
- **CPU:** Intel i5-10500T (or equivalent 4+ core CPU)
- **RAM:** 16GB minimum, 32GB recommended for LLMs
- **Storage:** 512GB SSD minimum
- **Network:** Gigabit Ethernet (static IP recommended)

### Software
- Ubuntu Server 24.04 LTS (or Debian 12)
- Docker Engine 24.0+
- Docker Compose v2.20+

## Step 1: Prepare Ubuntu Server

### 1.1 Install Ubuntu Server

Download Ubuntu Server 24.04 LTS and install it on your OptiPlex.

**During installation:**
- Enable OpenSSH server
- Create an admin user (not root)
- Optionally set a static IP address

### 1.2 Update System

```bash
# SSH into your OptiPlex
ssh admin@<OPTIPLEX_IP>

# Update system packages
sudo apt update && sudo apt upgrade -y

# Install prerequisites
sudo apt install -y git curl vim htop

# Reboot if kernel was updated
sudo reboot
```

### 1.3 Configure Static IP (Recommended)

If you didn't set a static IP during installation:

```bash
# Edit netplan configuration
sudo nano /etc/netplan/00-installer-config.yaml
```

Example static IP configuration:

```yaml
network:
  version: 2
  ethernets:
    eno1:  # Your interface name (check with: ip link)
      addresses:
        - 192.168.1.100/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
```

Apply the configuration:

```bash
sudo netplan apply
```

## Step 2: Install Docker

### 2.1 Install Docker Engine

```bash
# Install Docker using the official convenience script
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add your user to the docker group
sudo usermod -aG docker $USER

# Log out and back in for group change to take effect
exit
```

SSH back in after logging out.

### 2.2 Verify Docker Installation

```bash
# Check Docker version
docker --version
# Should show: Docker version 24.0.x or higher

# Check Docker Compose version
docker compose version
# Should show: Docker Compose version v2.20.x or higher

# Verify you can run Docker without sudo
docker run hello-world
```

## Step 3: Clone and Bootstrap

### 3.1 Clone the Repository

```bash
cd ~
git clone https://github.com/orionsentinel/Orion-Sentinel-DataAICore.git
cd Orion-Sentinel-DataAICore
```

### 3.2 Run Bootstrap Script

The bootstrap script creates directories, generates secrets, and initializes configuration:

```bash
./scripts/bootstrap-dataaicore.sh
```

**What the bootstrap script does:**
- ✅ Checks Docker and Docker Compose are installed
- ✅ Creates data directory structure under `/srv/orion/dataaicore`
- ✅ Copies `env/.env.example` to `.env`
- ✅ Generates secure random secrets for databases and services
- ✅ Creates the `dataaicore_internal` Docker network
- ✅ Prints next steps

### 3.3 Configure Environment

Review and customize the `.env` file:

```bash
sudo nano .env
```

**Key settings to verify:**

```bash
# Your OptiPlex's LAN IP address
HOST_IP=192.168.1.100

# Timezone
TZ=Europe/Amsterdam

# Data storage root
DATA_ROOT=/srv/orion/dataaicore

# Nextcloud admin credentials (auto-generated)
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=<generated-secure-password>

# Domain for optional public Nextcloud (Phase 2)
ORION_DOMAIN=yourdomain.com
```

**Important:** Set `HOST_IP` to your OptiPlex's actual LAN IP address.

## Step 4: Start Services

### 4.1 Start the Core Bundle

Start all primary services (Nextcloud + SearXNG + LLM):

```bash
./scripts/orionctl up core
```

This starts:
- Nextcloud + Postgres + Redis
- SearXNG web search
- Ollama + Open WebUI

### 4.2 Verify Services

Check that all services are running:

```bash
./scripts/orionctl ps
```

Expected output:

```
NAME                              STATUS    PORTS
orion_dataaicore_nextcloud        Up        192.168.1.100:8080->80/tcp
orion_dataaicore_postgres         Up
orion_dataaicore_redis            Up
orion_dataaicore_searxng          Up        192.168.1.100:8888->8080/tcp
orion_dataaicore_ollama           Up
orion_dataaicore_openwebui        Up        192.168.1.100:3000->8080/tcp
```

### 4.3 Run Health Check

```bash
./scripts/orionctl doctor
```

This verifies:
- Docker daemon is running
- All containers are healthy
- Ports are accessible
- Disk space is adequate

## Step 5: Access Services

### 5.1 Nextcloud

1. Open browser: `http://<HOST_IP>:8080`
2. Log in with credentials from `.env`:
   - Username: `admin` (or value of `NEXTCLOUD_ADMIN_USER`)
   - Password: (value of `NEXTCLOUD_ADMIN_PASSWORD` from `.env`)
3. Complete the initial setup wizard

**First-time Nextcloud setup:**
- Choose apps to install (Calendar, Contacts, Tasks recommended)
- Configure external storage if needed
- Set up mobile apps (iOS/Android Nextcloud app)

### 5.2 SearXNG

1. Open browser: `http://<HOST_IP>:8888`
2. Start searching! No login required.
3. Results come from multiple search engines (DuckDuckGo, Brave, etc.)

**Note:** SearXNG provides privacy-focused web search. It does NOT index local documents in Phase 1.

### 5.3 Open WebUI (AI Chat)

1. Open browser: `http://<HOST_IP>:3000`
2. Create an account (first user becomes admin)
3. Select a model from the dropdown (see Step 6 to pull models)
4. Start chatting!

## Step 6: Pull LLM Models

After starting services, pull an LLM model for Open WebUI:

### 6.1 Using the Helper Script

```bash
# Pull a small, CPU-friendly model (recommended)
./scripts/pull-model.sh llama3.2:3b

# Or pull a different model
./scripts/pull-model.sh qwen2.5:3b
```

### 6.2 Model Size Guide

| Model | Download Size | RAM Usage | Speed |
|-------|---------------|-----------|-------|
| `llama3.2:3b` | ~2GB | ~4GB | Fast on CPU |
| `qwen2.5:3b` | ~2GB | ~4GB | Fast on CPU |
| `llama3.2:7b` | ~4GB | ~8GB | Slow on CPU |
| `mistral:7b` | ~4GB | ~8GB | Slow on CPU |

**Recommendation:** Start with `llama3.2:3b` or `qwen2.5:3b` for best CPU performance.

### 6.3 List Available Models

```bash
docker exec orion_dataaicore_ollama ollama list
```

## Step 7: Configure Open WebUI to Use SearXNG (Optional)

You can configure Open WebUI to use SearXNG for web search during conversations:

1. Log into Open WebUI as admin
2. Go to **Settings** → **Web Search**
3. Configure:
   - **Search Engine:** SearXNG
   - **URL:** `http://searxng:8080`
   - **Query Parameter:** `q`
   - **Result Format:** `json`
4. Save settings

Now the AI can search the web during conversations when you enable web search.

See [CONFIGURATION.md](CONFIGURATION.md) for detailed setup steps.

## Step 8: Verify Installation

Run the complete verification:

```bash
# 1. Check all services are running
./scripts/orionctl ps

# 2. Run health checks
./scripts/orionctl doctor

# 3. Check disk space
df -h /srv/orion/dataaicore

# 4. View logs for any errors
./scripts/orionctl logs
```

## Post-Installation Tasks

### Set Up Automatic Startup (Optional)

To start DataAICore automatically on boot:

```bash
# Copy systemd service file
sudo cp systemd/dataaicore.service /etc/systemd/system/

# Edit the service file to set your user
sudo nano /etc/systemd/system/dataaicore.service
# Change User= and Group= to your username

# Enable and start
sudo systemctl enable dataaicore
sudo systemctl start dataaicore
```

### Set Up Backups

See [OPERATIONS.md](OPERATIONS.md) for backup procedures.

Minimum backup:
- Nextcloud database: `${DATA_ROOT}/nextcloud/postgres`
- Nextcloud files: `${DATA_ROOT}/nextcloud/app` and `data`
- Configuration: `.env` file

### Update Services

```bash
# Pull latest images and restart
./scripts/orionctl update
```

## Troubleshooting

### Can't access Nextcloud

```bash
# Check if container is running
docker ps | grep nextcloud

# Check logs
./scripts/orionctl logs nextcloud

# Verify port is listening
ss -lntp | grep 8080
```

### Can't access SearXNG

```bash
# Check if container is running
docker ps | grep searxng

# Check logs
./scripts/orionctl logs searxng

# Verify port is listening
ss -lntp | grep 8888
```

### Ollama model download fails

```bash
# Check disk space
df -h

# Check Ollama logs
./scripts/orionctl logs ollama

# Try a smaller model
./scripts/pull-model.sh llama3.2:3b
```

### Open WebUI can't connect to Ollama

```bash
# Check Ollama is running
docker exec orion_dataaicore_ollama ollama list

# Check network connectivity
docker exec orion_dataaicore_openwebui wget -qO- http://ollama:11434/api/tags

# Restart services
./scripts/orionctl down
./scripts/orionctl up llm
```

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for more solutions.

## Next Steps

1. **Nextcloud:** Install apps, set up mobile sync, configure external storage
2. **SearXNG:** Customize search engines in settings
3. **LLM:** Experiment with different models and prompts
4. **Security:** Review [SECURITY.md](SECURITY.md)
5. **Operations:** Set up backups per [OPERATIONS.md](OPERATIONS.md)

## Optional: Public Nextcloud (Phase 2)

⚠️ **Only proceed if you want Nextcloud accessible from the internet!**

See [SECURITY.md](SECURITY.md) for requirements and setup.

**Prerequisites:**
- Domain name (e.g., `cloud.yourdomain.com`)
- DNS A record pointing to your public IP
- Router port forwarding: 443 → OptiPlex IP

**Enable public access:**

```bash
# Edit .env and set your domain
sudo nano .env
# Set: ORION_DOMAIN=yourdomain.com

# Start with public-nextcloud profile
./scripts/orionctl down
./scripts/orionctl up nextcloud public-nextcloud
```

---

**Installation complete!** Your self-hosted cloud and AI stack is ready. 🚀
