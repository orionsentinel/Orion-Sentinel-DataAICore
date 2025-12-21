# Orion-Sentinel-DataAICore Operations Guide

Day-to-day operations, maintenance, and backup procedures.

## Service Management

### Using orionctl

The `orionctl` script is the primary interface for managing services.

```bash
# Location
./scripts/orionctl <command> [options]
```

### Starting Services

```bash
# Start individual stacks
./scripts/orionctl up nextcloud    # Nextcloud + Postgres + Redis
./scripts/orionctl up websearch    # SearXNG
./scripts/orionctl up llm          # Ollama + Open WebUI

# Start bundle (all core services)
./scripts/orionctl up core

# Start with specific profiles
./scripts/orionctl up nextcloud websearch

# Optional: Public Nextcloud (Phase 2)
./scripts/orionctl up nextcloud public-nextcloud
```

### Stopping Services

```bash
# Stop all services
./scripts/orionctl down

# Stop specific stack
./scripts/orionctl down nextcloud
./scripts/orionctl down websearch
./scripts/orionctl down llm
```

### Viewing Status

```bash
# List running containers
./scripts/orionctl ps

# View logs (all services)
./scripts/orionctl logs

# View logs for specific service
./scripts/orionctl logs nextcloud
./scripts/orionctl logs searxng
./scripts/orionctl logs ollama

# Follow logs in real-time
./scripts/orionctl logs -f nextcloud
```

### Health Check

```bash
./scripts/orionctl doctor
```

Checks:
- Docker daemon status
- Disk space
- Container health
- Network connectivity
- Port availability

---

## Updates

### Update Docker Images

```bash
# Pull latest images and restart
./scripts/orionctl update

# Or manually:
./scripts/orionctl down
docker compose pull
./scripts/orionctl up core
```

### Update LLM Models

```bash
# List current models
docker exec orion_dataaicore_ollama ollama list

# Update a model
docker exec orion_dataaicore_ollama ollama pull llama3.2:3b

# Remove old models
docker exec orion_dataaicore_ollama ollama rm old-model:tag
```

---

## Backups

### What to Backup

| Data | Location | Priority |
|------|----------|----------|
| Nextcloud Database | `${DATA_ROOT}/nextcloud/postgres` | **Critical** |
| Nextcloud Files | `${DATA_ROOT}/nextcloud/app` and `data` | **Critical** |
| Configuration | `.env` file | **Critical** |
| Redis Cache | `${DATA_ROOT}/redis` | Optional |
| SearXNG Config | `${DATA_ROOT}/searxng` | Low |
| LLM Models | `${DATA_ROOT}/llm/ollama` | Low (can re-download) |
| Open WebUI Data | `${DATA_ROOT}/llm/openwebui` | Medium |

### Backup Nextcloud Database

```bash
# Create database dump
docker exec orion_dataaicore_postgres pg_dump -U nextcloud nextcloud > \
  ~/backups/nextcloud-db-$(date +%Y%m%d).sql

# Compressed dump
docker exec orion_dataaicore_postgres pg_dump -U nextcloud nextcloud | \
  gzip > ~/backups/nextcloud-db-$(date +%Y%m%d).sql.gz
```

### Backup Nextcloud Files

```bash
# Stop Nextcloud first (optional but recommended for consistency)
./scripts/orionctl down nextcloud

# Backup application data
sudo tar -czf ~/backups/nextcloud-app-$(date +%Y%m%d).tar.gz \
  /srv/orion/dataaicore/nextcloud/app

# Backup user data (can be large!)
sudo tar -czf ~/backups/nextcloud-data-$(date +%Y%m%d).tar.gz \
  /srv/orion/dataaicore/nextcloud/data

# Restart Nextcloud
./scripts/orionctl up nextcloud
```

### Backup Configuration

```bash
# Backup .env (contains secrets!)
cp .env ~/backups/.env.backup-$(date +%Y%m%d)

# Backup entire config directory
tar -czf ~/backups/config-$(date +%Y%m%d).tar.gz \
  .env env/ stacks/websearch/searxng/
```

### Automated Backup Script

Create a backup script:

```bash
cat > ~/backup-dataaicore.sh << 'EOF'
#!/bin/bash
set -e

BACKUP_DIR=~/backups/dataaicore
DATE=$(date +%Y%m%d-%H%M%S)
DATA_ROOT=/srv/orion/dataaicore

mkdir -p "$BACKUP_DIR"

echo "Backing up Nextcloud database..."
docker exec orion_dataaicore_postgres pg_dump -U nextcloud nextcloud | \
  gzip > "$BACKUP_DIR/nextcloud-db-$DATE.sql.gz"

echo "Backing up configuration..."
tar -czf "$BACKUP_DIR/config-$DATE.tar.gz" \
  ~/Orion-Sentinel-DataAICore/.env \
  ~/Orion-Sentinel-DataAICore/stacks/websearch/searxng/settings.yml

echo "Cleaning up old backups (keeping 7 days)..."
find "$BACKUP_DIR" -type f -mtime +7 -delete

echo "Backup complete: $BACKUP_DIR"
ls -la "$BACKUP_DIR"
EOF

chmod +x ~/backup-dataaicore.sh
```

Schedule with cron:

```bash
crontab -e
# Add: 0 2 * * * ~/backup-dataaicore.sh >> ~/backup.log 2>&1
```

---

## Restore

### Restore Nextcloud Database

```bash
# Stop Nextcloud
./scripts/orionctl down nextcloud

# Restore database
gunzip -c ~/backups/nextcloud-db-YYYYMMDD.sql.gz | \
  docker exec -i orion_dataaicore_postgres psql -U nextcloud nextcloud

# Start Nextcloud
./scripts/orionctl up nextcloud
```

### Restore Nextcloud Files

```bash
# Stop Nextcloud
./scripts/orionctl down nextcloud

# Restore files
sudo tar -xzf ~/backups/nextcloud-app-YYYYMMDD.tar.gz -C /

# Fix permissions
sudo chown -R www-data:www-data /srv/orion/dataaicore/nextcloud/app

# Start Nextcloud
./scripts/orionctl up nextcloud
```

---

## Monitoring

### Check Resource Usage

```bash
# Container resource usage
docker stats

# Disk usage
df -h /srv/orion/dataaicore
du -sh /srv/orion/dataaicore/*

# Memory usage
free -h
```

### Check Logs for Errors

```bash
# All services
./scripts/orionctl logs 2>&1 | grep -i error

# Specific service
./scripts/orionctl logs nextcloud 2>&1 | grep -i error
```

### Check Service Health

```bash
# Nextcloud
curl -s http://localhost:8080/status.php | jq

# SearXNG
curl -s http://localhost:8888/healthz

# Ollama
curl -s http://localhost:11434/api/tags | jq
```

---

## Maintenance Tasks

### Clean Up Docker

```bash
# Remove unused images
docker image prune -a

# Remove unused volumes (careful!)
docker volume prune

# Remove all unused data
docker system prune -a
```

### Nextcloud Maintenance

```bash
# Run Nextcloud maintenance
docker exec -u www-data orion_dataaicore_nextcloud php occ maintenance:mode --on
docker exec -u www-data orion_dataaicore_nextcloud php occ maintenance:repair
docker exec -u www-data orion_dataaicore_nextcloud php occ maintenance:mode --off

# Scan for new files
docker exec -u www-data orion_dataaicore_nextcloud php occ files:scan --all

# Clean up file cache
docker exec -u www-data orion_dataaicore_nextcloud php occ files:cleanup
```

### Database Maintenance

```bash
# Vacuum PostgreSQL
docker exec orion_dataaicore_postgres vacuumdb -U nextcloud --analyze nextcloud
```

---

## Scaling and Performance

### Increase PHP Memory

Edit `.env`:
```bash
PHP_MEMORY_LIMIT=1G
```

Then restart:
```bash
./scripts/orionctl down nextcloud
./scripts/orionctl up nextcloud
```

### Increase Upload Limits

Edit `.env`:
```bash
PHP_UPLOAD_MAX_SIZE=50G
PHP_MAX_EXECUTION_TIME=7200
```

### LLM Performance

For better LLM performance on CPU:
- Use smaller models (3B parameters)
- Increase system RAM
- Consider GPU acceleration (see CONFIGURATION.md)

---

## Troubleshooting

### Service Won't Start

```bash
# Check logs
./scripts/orionctl logs <service>

# Check Docker daemon
sudo systemctl status docker

# Validate compose files
docker compose config
```

### Port Already in Use

```bash
# Find what's using the port
sudo ss -lntp | grep :8080

# Kill the process or change port in .env
```

### Disk Full

```bash
# Check disk usage
df -h

# Find large files
du -sh /srv/orion/dataaicore/* | sort -h

# Clean Docker
docker system prune -a

# Remove old LLM models
docker exec orion_dataaicore_ollama ollama list
docker exec orion_dataaicore_ollama ollama rm <model>
```

### Database Connection Issues

```bash
# Check PostgreSQL is running
docker ps | grep postgres

# Check connectivity
docker exec orion_dataaicore_nextcloud nc -zv postgres 5432

# Check PostgreSQL logs
./scripts/orionctl logs postgres
```

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for more detailed solutions.

---

## Systemd Service

To run DataAICore as a system service:

```bash
# Install service
sudo cp systemd/dataaicore.service /etc/systemd/system/

# Edit to match your setup
sudo nano /etc/systemd/system/dataaicore.service

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable dataaicore
sudo systemctl start dataaicore

# Check status
sudo systemctl status dataaicore

# View logs
sudo journalctl -u dataaicore -f
```

---

## Emergency Procedures

### Service Completely Down

```bash
# 1. Check Docker
sudo systemctl status docker
sudo systemctl restart docker

# 2. Check containers
docker ps -a

# 3. Start services
./scripts/orionctl up core

# 4. Check logs
./scripts/orionctl logs
```

### Corrupted Database

```bash
# 1. Stop services
./scripts/orionctl down

# 2. Restore from backup
gunzip -c ~/backups/nextcloud-db-LATEST.sql.gz | \
  docker exec -i orion_dataaicore_postgres psql -U nextcloud nextcloud

# 3. Start services
./scripts/orionctl up core
```

### Full System Recovery

```bash
# 1. Fresh install (follow INSTALL.md)
# 2. Restore .env from backup
# 3. Restore database
# 4. Restore Nextcloud files
# 5. Start services
./scripts/orionctl up core
```
