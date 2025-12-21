# Orion-Sentinel-DataAICore Troubleshooting Guide

Common problems and solutions.

## Quick Diagnostics

Run the doctor command first:
```bash
./scripts/orionctl doctor
```

This checks:
- Docker daemon status
- Docker Compose version
- Container health
- Port availability
- Disk space
- Network connectivity

---

## Service Access Issues

### Can't Access Nextcloud

**Symptoms:** Browser shows "connection refused" or times out at `http://<IP>:8080`

**Solutions:**

1. **Check container is running:**
   ```bash
   docker ps | grep nextcloud
   ```

2. **Check port binding:**
   ```bash
   ss -lntp | grep 8080
   ```

3. **Check HOST_IP setting:**
   ```bash
   grep HOST_IP .env
   # Should be your LAN IP or 0.0.0.0
   ```

4. **Check container logs:**
   ```bash
   ./scripts/orionctl logs nextcloud
   ```

5. **Verify trusted domains:**
   ```bash
   docker exec orion_dataaicore_nextcloud cat /var/www/html/config/config.php | grep trusted
   ```

6. **Restart the stack:**
   ```bash
   ./scripts/orionctl down nextcloud
   ./scripts/orionctl up nextcloud
   ```

### Can't Access SearXNG

**Symptoms:** Browser shows error at `http://<IP>:8888`

**Solutions:**

1. **Check container is running:**
   ```bash
   docker ps | grep searxng
   ```

2. **Check logs for errors:**
   ```bash
   ./scripts/orionctl logs searxng
   ```

3. **Check settings.yml syntax:**
   ```bash
   # Validate YAML
   python3 -c "import yaml; yaml.safe_load(open('stacks/websearch/searxng/settings.yml'))"
   ```

4. **Restart SearXNG:**
   ```bash
   ./scripts/orionctl down websearch
   ./scripts/orionctl up websearch
   ```

### Can't Access Open WebUI

**Symptoms:** Browser shows error at `http://<IP>:3000`

**Solutions:**

1. **Check containers are running:**
   ```bash
   docker ps | grep -E "(ollama|openwebui)"
   ```

2. **Check Open WebUI logs:**
   ```bash
   ./scripts/orionctl logs openwebui
   ```

3. **Check Ollama is healthy:**
   ```bash
   docker exec orion_dataaicore_ollama ollama list
   ```

4. **Restart LLM stack:**
   ```bash
   ./scripts/orionctl down llm
   ./scripts/orionctl up llm
   ```

---

## Database Issues

### Nextcloud Database Connection Failed

**Symptoms:** Nextcloud shows database error on startup

**Solutions:**

1. **Check PostgreSQL is running:**
   ```bash
   docker ps | grep postgres
   ```

2. **Check PostgreSQL health:**
   ```bash
   docker exec orion_dataaicore_postgres pg_isready -U nextcloud
   ```

3. **Check PostgreSQL logs:**
   ```bash
   ./scripts/orionctl logs postgres
   ```

4. **Verify credentials match:**
   ```bash
   grep POSTGRES .env
   ```

5. **Restart database:**
   ```bash
   docker restart orion_dataaicore_postgres
   ```

### Database Initialization Failed

**Symptoms:** PostgreSQL won't start, logs show initialization errors

**Solutions:**

1. **Check disk space:**
   ```bash
   df -h /srv/orion/dataaicore
   ```

2. **Check permissions:**
   ```bash
   ls -la /srv/orion/dataaicore/nextcloud/postgres
   ```

3. **Remove and reinitialize (loses data!):**
   ```bash
   ./scripts/orionctl down
   sudo rm -rf /srv/orion/dataaicore/nextcloud/postgres/*
   ./scripts/orionctl up nextcloud
   ```

---

## Network Issues

### Docker Network Not Found

**Symptoms:** Error about `dataaicore_internal` or `dataaicore_lan` network

**Solutions:**

```bash
# Create networks manually
docker network create dataaicore_internal
docker network create dataaicore_lan

# Or run bootstrap again
./scripts/bootstrap-dataaicore.sh
```

### Container Can't Reach Other Containers

**Symptoms:** Services can't communicate (e.g., Open WebUI can't reach Ollama)

**Solutions:**

1. **Check networks exist:**
   ```bash
   docker network ls | grep dataaicore
   # Should show both dataaicore_internal and dataaicore_lan
   ```

2. **Check containers are on correct networks:**
   ```bash
   # Internal network should have all services
   docker network inspect dataaicore_internal --format '{{range .Containers}}{{.Name}} {{end}}'
   
   # LAN network should have only UI services
   docker network inspect dataaicore_lan --format '{{range .Containers}}{{.Name}} {{end}}'
   ```

3. **Verify internal connectivity:**
   ```bash
   # Test Nextcloud -> PostgreSQL
   docker exec orion_dataaicore_nextcloud ping postgres
   
   # Test Open WebUI -> Ollama
   docker exec orion_dataaicore_openwebui curl http://ollama:11434/api/tags
   ```

4. **Restart all services:**
   ```bash
   ./scripts/orionctl down
   ./scripts/orionctl up core
   ```

### Port Already in Use

**Symptoms:** Error `bind: address already in use`

**Solutions:**

1. **Find what's using the port:**
   ```bash
   sudo ss -lntp | grep :8080
   sudo lsof -i :8080
   ```

2. **Stop the conflicting service:**
   ```bash
   sudo systemctl stop <service>
   # or
   sudo kill <PID>
   ```

3. **Or change the port in .env:**
   ```bash
   sudo nano .env
   # For SearXNG: Change SEARXNG_PORT=8888 to different port
   # For Nextcloud/Open WebUI: Edit compose file
   
   # Restart services
   ./scripts/orionctl restart core
   ```

### Can't Access Services from Another Computer

**Symptoms:** Services work on OptiPlex but not from other devices on network

**Cause:** `HOST_IP=127.0.0.1` (localhost-only)

**Solutions:**

1. **Check current HOST_IP:**
   ```bash
   grep HOST_IP .env
   ```

2. **Change to LAN IP:**
   ```bash
   sudo nano .env
   # Change: HOST_IP=192.168.1.100  # your OptiPlex IP
   ```

3. **Restart services:**
   ```bash
   ./scripts/orionctl restart core
   ```

4. **Verify binding:**
   ```bash
   docker ps --format 'table {{.Names}}\t{{.Ports}}'
   # Should show: 192.168.1.100:8080->80/tcp
   ```

### Services Exposed on Wrong Network Interface

**Symptoms:** Services accessible on unexpected networks

**Solutions:**

1. **Check current bindings:**
   ```bash
   ss -lntp | grep -E ":(8080|8888|3000)"
   docker ps --format 'table {{.Names}}\t{{.Ports}}'
   ```

2. **Update HOST_IP:**
   ```bash
   sudo nano .env
   # Set to specific IP: HOST_IP=192.168.1.100
   # Or localhost only: HOST_IP=127.0.0.1
   ```

3. **Restart:**
   ```bash
   ./scripts/orionctl restart core
   ```

---

## LLM Issues

### Model Won't Download

**Symptoms:** `ollama pull` hangs or fails

**Solutions:**

1. **Check disk space:**
   ```bash
   df -h /srv/orion/dataaicore/llm/ollama
   # Models are 2-8GB each!
   ```

2. **Check network:**
   ```bash
   docker exec orion_dataaicore_ollama curl -I https://ollama.ai
   ```

3. **Try a smaller model:**
   ```bash
   ./scripts/pull-model.sh llama3.2:3b
   ```

4. **Check Ollama logs:**
   ```bash
   ./scripts/orionctl logs ollama
   ```

### Model Runs Out of Memory

**Symptoms:** Model loading fails, system becomes unresponsive

**Solutions:**

1. **Use smaller model:**
   ```bash
   ./scripts/pull-model.sh phi3:mini  # Very small
   ```

2. **Check system memory:**
   ```bash
   free -h
   ```

3. **Remove large models:**
   ```bash
   docker exec orion_dataaicore_ollama ollama rm llama3.2:7b
   ```

### Open WebUI Can't Connect to Ollama

**Symptoms:** "Failed to connect" error in Open WebUI

**Solutions:**

1. **Check Ollama is running:**
   ```bash
   docker exec orion_dataaicore_ollama ollama list
   ```

2. **Check Ollama API:**
   ```bash
   docker exec orion_dataaicore_openwebui curl http://ollama:11434/api/tags
   ```

3. **Check environment variable:**
   ```bash
   docker exec orion_dataaicore_openwebui env | grep OLLAMA
   # Should show: OLLAMA_BASE_URL=http://ollama:11434
   ```

4. **Restart both services:**
   ```bash
   ./scripts/orionctl down llm
   ./scripts/orionctl up llm
   ```

---

## SearXNG Issues

### No Search Results

**Symptoms:** SearXNG returns empty results

**Solutions:**

1. **Check internet connectivity:**
   ```bash
   docker exec orion_dataaicore_searxng curl -I https://duckduckgo.com
   ```

2. **Check settings.yml:**
   ```bash
   sudo nano stacks/websearch/searxng/settings.yml
   # Ensure engines are not disabled
   ```

3. **Some engines may be blocked:**
   - Try different search engines
   - Some engines use CAPTCHAs when overused
   - This is expected behavior

4. **Restart SearXNG:**
   ```bash
   ./scripts/orionctl down websearch
   ./scripts/orionctl up websearch
   ```

### SearXNG Configuration Error

**Symptoms:** SearXNG won't start, YAML errors in logs

**Solutions:**

1. **Validate YAML syntax:**
   ```bash
   python3 -c "import yaml; yaml.safe_load(open('stacks/websearch/searxng/settings.yml'))"
   ```

2. **Reset to default settings:**
   ```bash
   cp env/searxng-settings.yml.example stacks/websearch/searxng/settings.yml
   ```

3. **Check file permissions:**
   ```bash
   ls -la stacks/websearch/searxng/settings.yml
   ```

---

## Disk Space Issues

### Disk Full

**Symptoms:** Services fail, "no space left on device" errors

**Solutions:**

1. **Check disk usage:**
   ```bash
   df -h
   du -sh /srv/orion/dataaicore/*
   ```

2. **Clean Docker:**
   ```bash
   docker system prune -a
   docker volume prune
   ```

3. **Remove old LLM models:**
   ```bash
   docker exec orion_dataaicore_ollama ollama list
   docker exec orion_dataaicore_ollama ollama rm <old-model>
   ```

4. **Clean Nextcloud trash:**
   ```bash
   docker exec -u www-data orion_dataaicore_nextcloud php occ trashbin:cleanup --all-users
   ```

5. **Clean old backups:**
   ```bash
   find ~/backups -type f -mtime +30 -delete
   ```

---

## Permission Issues

### Permission Denied Errors

**Symptoms:** Services can't write to data directories

**Solutions:**

1. **Fix ownership:**
   ```bash
   sudo chown -R $USER:$USER /srv/orion/dataaicore
   ```

2. **Fix Nextcloud permissions:**
   ```bash
   sudo chown -R www-data:www-data /srv/orion/dataaicore/nextcloud/app
   ```

3. **Check SELinux (if enabled):**
   ```bash
   sudo sestatus
   # If enforcing, may need to set contexts
   ```

### User Not in Docker Group

**Symptoms:** "Permission denied" when running docker commands

**Solutions:**

```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in
exit
# SSH back in

# Verify
groups | grep docker
```

---

## Public Nextcloud Issues (Phase 2)

### SSL Certificate Not Working

**Symptoms:** Browser shows certificate error

**Solutions:**

1. **Check DNS:**
   ```bash
   nslookup cloud.yourdomain.com
   ```

2. **Check port 443 is forwarded:**
   ```bash
   # From outside your network:
   curl -I https://cloud.yourdomain.com
   ```

3. **Check Caddy logs:**
   ```bash
   ./scripts/orionctl logs caddy
   ```

4. **Verify Caddyfile:**
   ```bash
   cat stacks/public-nextcloud/proxy/Caddyfile
   ```

### Nextcloud Redirects Fail

**Symptoms:** Login loops or wrong URLs

**Solutions:**

1. **Check trusted domains:**
   ```bash
   docker exec orion_dataaicore_nextcloud cat /var/www/html/config/config.php | grep trusted
   ```

2. **Set overwrite settings:**
   ```bash
   docker exec -u www-data orion_dataaicore_nextcloud php occ config:system:set \
     overwriteprotocol --value=https
   docker exec -u www-data orion_dataaicore_nextcloud php occ config:system:set \
     overwrite.cli.url --value=https://cloud.yourdomain.com
   ```

---

## Getting Help

If none of the above solutions work:

1. **Collect diagnostics:**
   ```bash
   ./scripts/orionctl doctor > diagnostics.txt
   ./scripts/orionctl logs > logs.txt
   docker ps -a >> diagnostics.txt
   ```

2. **Check existing issues:**
   https://github.com/orionsentinel/Orion-Sentinel-DataAICore/issues

3. **Create a new issue** with:
   - Description of the problem
   - Steps to reproduce
   - Diagnostic output
   - Relevant log snippets
