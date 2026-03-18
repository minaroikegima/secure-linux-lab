#!/usr/bin/env bash
# CIS Ubuntu Level 1 Hardening Script
# Usage: sudo ./cis-harden.sh

[[ $EUID -ne 0 ]] && { echo "ERROR: Run as root"; exit 1; }

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
LOG_FILE="/var/log/cis-hardening-$(date +%Y%m%d).log"

log()  { echo -e "${BLUE}[CIS]${NC}   $*" | tee -a "$LOG_FILE"; }
ok()   { echo -e "${GREEN}[PASS]${NC} $*" | tee -a "$LOG_FILE"; PASS=$((PASS+1)); }
fail() { echo -e "${RED}[FAIL]${NC} $*" | tee -a "$LOG_FILE"; FAIL=$((FAIL+1)); }
warn() { echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE"; }

echo "" | tee -a "$LOG_FILE"
echo "════════════════════════════════════════════" | tee -a "$LOG_FILE"
echo "  CIS Ubuntu 22.04 Level 1 Hardening" | tee -a "$LOG_FILE"
echo "  Started: $(date)" | tee -a "$LOG_FILE"
echo "════════════════════════════════════════════" | tee -a "$LOG_FILE"

# Section 1 - Filesystem
log "Section 1: Filesystem Configuration"
for fs in cramfs freevxfs jffs2 hfs hfsplus udf; do
  echo "install $fs /bin/true" >> /etc/modprobe.d/cis-disable-fs.conf 2>/dev/null && \
  echo "blacklist $fs" >> /etc/modprobe.d/cis-disable-fs.conf 2>/dev/null && \
  ok "Disabled filesystem module: $fs" || \
  fail "Could not disable: $fs"
done

chmod 1777 /tmp && ok "Set sticky bit on /tmp" || fail "Could not set /tmp permissions"

# Section 2 - Services
log "Section 2: Disable Unnecessary Services"
for svc in avahi-daemon cups rpcbind rsync; do
  if systemctl is-enabled "$svc" &>/dev/null 2>&1; then
    systemctl disable --now "$svc" 2>/dev/null && \
    ok "Disabled service: $svc" || \
    fail "Could not disable: $svc"
  else
    ok "Already disabled: $svc"
  fi
done

# Section 3 - Network
log "Section 3: Network Hardening"
conf="/etc/sysctl.d/99-cis-hardening.conf"
echo "# CIS Hardening" > "$conf"

params=(
  "net.ipv4.ip_forward=0"
  "net.ipv4.conf.all.send_redirects=0"
  "net.ipv4.conf.all.accept_redirects=0"
  "net.ipv4.conf.all.log_martians=1"
  "net.ipv4.tcp_syncookies=1"
  "kernel.randomize_va_space=2"
  "kernel.dmesg_restrict=1"
  "fs.protected_hardlinks=1"
  "fs.protected_symlinks=1"
)

for param in "${params[@]}"; do
  echo "$param" >> "$conf"
  key="${param%%=*}"
  value="${param##*=}"
  sysctl -w "$key=$value" > /dev/null 2>&1 && \
  ok "Applied sysctl: $param" || \
  fail "Could not apply: $param"
done

# Section 4 - Auditing
log "Section 4: Logging and Auditing"
apt-get install -y auditd -qq 2>/dev/null && \
ok "auditd installed" || \
fail "Could not install auditd"

cat > /etc/audit/rules.d/99-cis.rules << 'RULES'
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/ssh/sshd_config -p wa -k sshd
-a always,exit -F arch=b64 -S adjtimex -k time-change
-e 2
RULES

systemctl enable --now auditd 2>/dev/null && \
ok "auditd running" || \
fail "Could not start auditd"

# Section 5 - SSH
log "Section 5: SSH Hardening"
sshd_config="/etc/ssh/sshd_config"

settings=(
  "PermitRootLogin no"
  "PasswordAuthentication no"
  "PermitEmptyPasswords no"
  "X11Forwarding no"
  "MaxAuthTries 3"
  "LoginGraceTime 60"
)

for setting in "${settings[@]}"; do
  key="${setting%% *}"
  if grep -q "^#*${key}" "$sshd_config" 2>/dev/null; then
    sed -i "s|^#*${key}.*|${setting}|" "$sshd_config" && \
    ok "SSH: $setting" || \
    fail "Could not set SSH: $setting"
  else
    echo "$setting" >> "$sshd_config" && \
    ok "SSH: $setting added" || \
    fail "Could not add SSH: $setting"
  fi
done

systemctl reload ssh 2>/dev/null && \
ok "SSH reloaded" || \
warn "Could not reload SSH"

# Section 6 - File Permissions
log "Section 6: File Permissions"
declare -A file_perms=(
  ["/etc/passwd"]="644"
  ["/etc/shadow"]="640"
  ["/etc/group"]="644"
  ["/etc/gshadow"]="640"
)

for path in "${!file_perms[@]}"; do
  mode="${file_perms[$path]}"
  if [[ -f "$path" ]]; then
    chmod "$mode" "$path" && \
    ok "Set $mode on $path" || \
    fail "Could not set permissions on $path"
  fi
done

# Summary
echo "" | tee -a "$LOG_FILE"
echo "════════════════════════════════════════════" | tee -a "$LOG_FILE"
echo "  Hardening Complete — $(date)" | tee -a "$LOG_FILE"
echo "  Log: $LOG_FILE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo -e "  ${GREEN}PASS: $PASS${NC}" | tee -a "$LOG_FILE"
echo -e "  ${RED}FAIL: $FAIL${NC}" | tee -a "$LOG_FILE"
echo "  Total: $((PASS+FAIL))" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "  Reboot recommended to apply all changes" | tee -a "$LOG_FILE"
echo "════════════════════════════════════════════" | tee -a "$LOG_FILE"
