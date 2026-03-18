# Infrastructure Recovery Playbook

A step by step guide for recovering from common infrastructure failures.

---

## Scenario 1 — High CPU Usage

### Symptoms
- CPU above 85% for more than 5 minutes
- System responding slowly
- Prometheus firing HighCPUUsage alert

### Recovery Steps
```bash
# Step 1 - Identify the process using most CPU
top -bn1 | head -20

# Step 2 - Find the exact process
ps aux --sort=-%cpu | head -10

# Step 3 - Check if it is a known process
systemctl status <service-name>

# Step 4 - If safe to restart
systemctl restart <service-name>

# Step 5 - If process is unknown and suspicious
kill -9 <PID>

# Step 6 - Verify CPU is back to normal
mpstat 1 5
```

### Prevention
- Set resource limits on services using systemd
- Configure auto-restart policies
- Review cron jobs that may be running unexpectedly

---

## Scenario 2 — High Memory Usage

### Symptoms
- RAM above 85% for more than 5 minutes
- System swapping heavily
- Prometheus firing HighMemoryUsage alert

### Recovery Steps
```bash
# Step 1 - Check memory usage
free -h

# Step 2 - Find processes using most memory
ps aux --sort=-%mem | head -10

# Step 3 - Check for memory leaks
cat /proc/<PID>/status | grep VmRSS

# Step 4 - Clear system cache safely
sync && echo 3 > /proc/sys/vm/drop_caches

# Step 5 - Restart the offending service
systemctl restart <service-name>

# Step 6 - Verify memory is back to normal
free -h
```

### Prevention
- Set memory limits in application configs
- Monitor for memory leaks regularly
- Configure swap space as a safety net

---

## Scenario 3 — Disk Space Low

### Symptoms
- Disk above 80% full
- Applications failing to write logs
- Prometheus firing DiskSpaceLow alert

### Recovery Steps
```bash
# Step 1 - Check disk usage
df -h

# Step 2 - Find largest files and folders
du -sh /* 2>/dev/null | sort -rh | head -20

# Step 3 - Clean up log files
journalctl --vacuum-size=100M
find /var/log -name "*.gz" -delete

# Step 4 - Clean up old packages
apt-get autoremove -y
apt-get clean

# Step 5 - Find and remove large temp files
find /tmp -size +100M -delete

# Step 6 - Verify disk space is recovered
df -h
```

### Prevention
- Configure log rotation
- Set up automatic cleanup cron jobs
- Monitor disk usage trends in Grafana

---

## Scenario 4 — Host Unreachable

### Symptoms
- Server not responding to ping
- SSH connection refused
- Prometheus firing HostDown alert

### Recovery Steps
```bash
# Step 1 - Verify the host is actually down
ping -c 5 <host-ip>

# Step 2 - Try SSH connection
ssh -v user@<host-ip>

# Step 3 - Check from another server
ping -c 5 <host-ip>

# Step 4 - Check VirtualBox/cloud console
# Log into VirtualBox and check VM status

# Step 5 - If VM is running but SSH is down
# Connect via console and check SSH service
systemctl status ssh
systemctl restart ssh

# Step 6 - Check firewall rules
ufw status
ufw allow 22/tcp
```

### Prevention
- Configure SSH keep-alive settings
- Set up redundant access methods
- Monitor network connectivity proactively

---

## Scenario 5 — Service Failure

### Symptoms
- Application returning errors
- Service showing failed status
- Logs showing error messages

### Recovery Steps
```bash
# Step 1 - Check service status
systemctl status <service-name>

# Step 2 - Check recent logs
journalctl -u <service-name> -n 50

# Step 3 - Attempt restart
systemctl restart <service-name>

# Step 4 - If restart fails check config
<service-name> --test-config

# Step 5 - Roll back to last working config
git log /etc/<service-name>/
git checkout <last-good-commit> /etc/<service-name>/config

# Step 6 - Verify service is healthy
systemctl is-active <service-name>
curl -f http://localhost:<port>/healthz
```

### Prevention
- Always test config changes before applying
- Keep config files in version control
- Use CI/CD to validate configs automatically
