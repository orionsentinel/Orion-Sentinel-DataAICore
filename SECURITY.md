# Orion-Sentinel-DataAICore Security Guide

Security guidelines and best practices for your self-hosted stack.

## Security Posture Summary

| Aspect | Default | Notes |
|--------|---------|-------|
| Network Exposure | **LAN-only** | No public internet access |
| Authentication | Per-service | Each service has its own auth |
| Encryption | TLS on public only | Internal network is unencrypted |
| Secrets | Auto-generated | Strong random passwords |
| Containers | Non-privileged | `no-new-privileges` set |

---

## Local-Only by Default

All services are configured for **LAN-only access** by default:

- Nextcloud: `${HOST_IP}:8080` (LAN)
- SearXNG: `${HOST_IP}:8888` (LAN)
- Open WebUI: `${HOST_IP}:3000` (LAN)

**No services are exposed to the internet** unless you explicitly enable the `public-nextcloud` profile.

### Verify Local-Only Status

```bash
# Check which ports are listening
ss -lntp | grep -E ":(8080|8888|3000|80|443)"

# Check Docker container port mappings
docker ps --format 'table {{.Names}}\t{{.Ports}}'
```

**Expected output:**
- Nextcloud: `127.0.0.1:8080->80/tcp` or `<LAN_IP>:8080->80/tcp`
- SearXNG: `127.0.0.1:8888->8080/tcp` or `<LAN_IP>:8888->8080/tcp`
- Open WebUI: `127.0.0.1:3000->8080/tcp` or `<LAN_IP>:3000->8080/tcp`
- PostgreSQL, Redis, Ollama: No published ports (internal only)

**WARNING:** If you see `0.0.0.0:PORT` bindings for services other than Caddy, your services may be exposed to all network interfaces. Update `HOST_IP` in `.env` to your specific LAN IP or `127.0.0.1`.

### Firewall Configuration

Even though services are LAN-only by default, consider enabling a firewall:

```bash
# Install UFW
sudo apt install ufw

# Allow SSH
sudo ufw allow ssh

# Allow LAN access to services
sudo ufw allow from 192.168.0.0/16 to any port 8080  # Nextcloud
sudo ufw allow from 192.168.0.0/16 to any port 8888  # SearXNG
sudo ufw allow from 192.168.0.0/16 to any port 3000  # Open WebUI

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status
```

---

## Service-Specific Security

### Nextcloud

**Default protections:**
- Strong auto-generated admin password
- Database password auto-generated
- Redis password auto-generated
- Trusted domains restrict access
- Bound to HOST_IP (default: 127.0.0.1 or LAN IP)

**Recommended actions:**
1. Change admin password after first login
2. Enable two-factor authentication (2FA)
3. Review and update trusted domains
4. Enable brute force protection (on by default)
5. Keep Nextcloud updated

**Enable 2FA:**
1. Log into Nextcloud as admin
2. Go to **Settings** → **Security**
3. Enable **Two-Factor Authentication**
4. Configure TOTP app (e.g., Google Authenticator)

### SearXNG

**Default protections:**
- No user authentication (by design)
- Limiter disabled (no rate limiting in Phase 1)
- Private by design (no tracking)
- Bound to HOST_IP (default: 127.0.0.1 or LAN IP)

**Important:** 
⚠️ **DO NOT expose SearXNG to the internet!**

SearXNG is designed for personal/private use. Exposing it publicly will:
- Attract abuse and bot traffic
- Get your IP blocked by search engines
- Potentially violate search engine ToS

### Open WebUI

**Default protections:**
- User authentication required
- First user becomes admin
- Sessions encrypted with secret key
- Bound to HOST_IP (default: 127.0.0.1 or LAN IP)

**Recommended actions:**
1. Create admin account immediately after setup
2. Set `ENABLE_SIGNUP=false` in `.env` after creating accounts
3. Use strong passwords
4. Regularly review user list

**Disable signup after setup:**
```bash
# Edit .env
sudo nano .env
# Change: ENABLE_SIGNUP=false

# Restart
./scripts/orionctl down llm
./scripts/orionctl up llm
```

### Ollama

**Default protections:**
- **Not exposed to network** (internal only, no published ports)
- **Internal Docker network only** - accessible only by Open WebUI
- No external API access by default
- Hardcoded to bind to 0.0.0.0 inside container (but not published)

**Note:** Ollama has no built-in authentication. It is configured to be accessible **ONLY** within the Docker internal network. Never expose Ollama to the LAN or internet without additional security layers.

**Network Configuration:**
- Connected to: `dataaicore_internal` only
- NOT connected to: `dataaicore_lan`
- No published ports (API accessible only by other containers)

If you need to expose Ollama API to LAN (NOT recommended):
```yaml
# Uncomment in stacks/llm/compose.yaml
ports:
  - "${HOST_IP:-127.0.0.1}:11434:11434"
# Then also add to networks:
#   - lan
```

---

## Public Nextcloud (Phase 2)

⚠️ **Only enable if you understand the risks and requirements!**

### Prerequisites Checklist

Before enabling public Nextcloud access:

- [ ] Domain name configured (DNS A record → your public IP)
- [ ] Router port forwarding: 443 → OptiPlex IP
- [ ] Strong Nextcloud admin password set
- [ ] 2FA enabled for all users
- [ ] Trusted domains include your public domain
- [ ] System fully updated

### Enable Public Access

```bash
# 1. Edit .env
sudo nano .env

# Set your domain
ORION_DOMAIN=yourdomain.com

# Add to trusted domains
NEXTCLOUD_TRUSTED_DOMAINS=192.168.1.100 localhost cloud.yourdomain.com

# 2. Start with public-nextcloud profile
./scripts/orionctl down
./scripts/orionctl up nextcloud public-nextcloud
```

### Verify Secure Configuration

After enabling:

```bash
# 1. Check only Nextcloud is exposed
ss -lntp | grep -E '^LISTEN.*(80|443)'
# Should only show Caddy on ports 80 and 443

# 2. Verify SSL certificate
curl -I https://cloud.yourdomain.com
# Should show HTTP/2 200 with valid certificate

# 3. Verify other services are NOT exposed
curl -I https://search.yourdomain.com  # Should fail
curl -I https://ai.yourdomain.com      # Should fail
```

### Security Hardening for Public Access

1. **Enable 2FA for all users**
2. **Set strong passwords** (12+ characters, mixed case, numbers, symbols)
3. **Keep system updated**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ./scripts/orionctl update
   ```
4. **Monitor access logs**
   ```bash
   ./scripts/orionctl logs caddy | grep -v health
   ```
5. **Configure fail2ban** (optional but recommended)
   ```bash
   sudo apt install fail2ban
   # Configure for Nextcloud: /etc/fail2ban/jail.d/nextcloud.conf
   ```

### What Gets Exposed

| Service | Public | Notes |
|---------|--------|-------|
| Nextcloud | ✅ Yes | Via `cloud.${ORION_DOMAIN}` |
| SearXNG | ❌ No | Remains LAN-only |
| Open WebUI | ❌ No | Remains LAN-only |
| Ollama | ❌ No | Internal only |
| PostgreSQL | ❌ No | Internal only |
| Redis | ❌ No | Internal only |

The Caddy reverse proxy **only** routes traffic to Nextcloud. Other services are **never** exposed.

---

## Secrets Management

### Auto-Generated Secrets

The bootstrap script generates strong random secrets:

- `NEXTCLOUD_ADMIN_PASSWORD` - Nextcloud admin password
- `POSTGRES_PASSWORD` - Database password
- `REDIS_PASSWORD` - Cache password
- `SEARXNG_SECRET_KEY` - SearXNG cookie secret
- `WEBUI_SECRET_KEY` - Open WebUI session secret

These are stored in `.env` which is git-ignored.

### Secret Rotation

To rotate secrets:

```bash
# 1. Generate new secret
openssl rand -base64 32

# 2. Update .env
sudo nano .env

# 3. Restart affected services
./scripts/orionctl down
./scripts/orionctl up core
```

**Note:** Rotating the database password requires additional steps:
```bash
# Update password in PostgreSQL
docker exec -it orion_dataaicore_postgres psql -U postgres
ALTER USER nextcloud WITH PASSWORD 'new-password';
\q

# Update .env
sudo nano .env
# Change POSTGRES_PASSWORD

# Restart
./scripts/orionctl down
./scripts/orionctl up core
```

### Backup Secrets

```bash
# Store .env securely
cp .env ~/backups/.env.$(date +%Y%m%d)

# Encrypt backup
gpg -c ~/backups/.env.$(date +%Y%m%d)
```

---

## Container Security

All containers run with security restrictions:

```yaml
security_opt:
  - no-new-privileges:true
```

This prevents privilege escalation within containers.

### Additional Hardening

For maximum security:

```yaml
# Add to container definitions
read_only: true          # Read-only filesystem (where possible)
cap_drop:
  - ALL                  # Drop all capabilities
cap_add:
  - NET_BIND_SERVICE     # Add only what's needed
```

---

## Network Security

### Docker Network Isolation

DataAICore uses a dual-network architecture for enhanced security:

**Network Topology:**
- `dataaicore_internal` - Internal network for service-to-service communication
  - All services connect to this network
  - Enables containers to communicate by service name
  - No external access without published ports
  
- `dataaicore_lan` - LAN-accessible network  
  - Only UI services (nextcloud, searxng, openwebui, caddy) connect to this
  - Services with published ports use this network for external access
  - Internal services (postgres, redis, ollama) are NOT on this network

**Service Network Configuration:**

| Service | Internal Network | LAN Network | Published Ports |
|---------|-----------------|-------------|-----------------|
| PostgreSQL | ✅ | ❌ | None (internal only) |
| Redis | ✅ | ❌ | None (internal only) |
| Ollama | ✅ | ❌ | None (internal only) |
| Nextcloud | ✅ | ✅ | `${HOST_IP}:8080` |
| Nextcloud Cron | ✅ | ❌ | None |
| SearXNG | ✅ | ✅ | `${HOST_IP}:8888` |
| Open WebUI | ✅ | ✅ | `${HOST_IP}:3000` |
| Caddy | ✅ | ✅ | `0.0.0.0:80,443` |

### Verify Network Isolation

Check that services are properly isolated:

```bash
# List Docker networks
docker network ls | grep dataaicore

# Inspect internal network (should show all services)
docker network inspect dataaicore_internal

# Inspect LAN network (should show only UI services)
docker network inspect dataaicore_lan

# Check which containers are on each network
docker network inspect dataaicore_internal --format '{{range .Containers}}{{.Name}} {{end}}'
docker network inspect dataaicore_lan --format '{{range .Containers}}{{.Name}} {{end}}'
```

**Expected output:**
- Internal network: postgres, redis, nextcloud, nextcloud-cron, searxng, ollama, openwebui, caddy
- LAN network: nextcloud, searxng, openwebui, caddy only

### Restrict External Access

To bind services to a specific interface only:

```bash
# Edit .env
HOST_IP=192.168.1.100  # Your LAN IP (not 0.0.0.0)
```

---

## Security Checklist

### Initial Setup

- [ ] Strong admin passwords set
- [ ] `.env` file has proper permissions (`chmod 600 .env`)
- [ ] Firewall configured
- [ ] Docker group limited to trusted users
- [ ] System fully updated

### Before Enabling Public Access

- [ ] 2FA enabled for all Nextcloud users
- [ ] Strong passwords enforced
- [ ] SSL certificate working
- [ ] Only Nextcloud exposed (verified with ss/netstat)
- [ ] Brute force protection enabled
- [ ] Backup system working

### Regular Maintenance

- [ ] Apply security updates monthly
- [ ] Review access logs weekly
- [ ] Rotate passwords annually
- [ ] Test backup restoration quarterly

---

## Incident Response

### Signs of Compromise

Watch for:
- Unexpected containers running
- Unusual network traffic
- Failed login attempts
- Unauthorized file changes
- High resource usage

### Check for Issues

```bash
# Check running containers
docker ps -a

# Check container logs
./scripts/orionctl logs | grep -i error

# Check system logs
sudo journalctl -xe

# Check login attempts (if fail2ban enabled)
sudo fail2ban-client status
```

### Response Steps

1. **Isolate:** Disconnect from internet
2. **Assess:** Check logs and containers
3. **Contain:** Stop compromised services
4. **Recover:** Restore from backup
5. **Review:** Determine root cause
6. **Harden:** Fix vulnerability

---

## Reporting Security Issues

If you discover a security vulnerability in this project:

1. **Do not** create a public issue
2. Contact the maintainers privately
3. Provide detailed information about the vulnerability
4. Allow time for a fix before public disclosure
