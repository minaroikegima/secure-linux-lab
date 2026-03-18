#!/usr/bin/env bash
# CIS Ubuntu Level 1 Audit Script
# Usage: sudo ./cis-audit.sh

[[ $EUID -ne 0 ]] && { echo "ERROR: Run as root"; exit 1; }

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0

ok()   { echo -e "${GREEN}[PASS]${NC} $*"; PASS=$((PASS+1)); }
fail() { echo -e "${RED}[FAIL]${NC} $*"; FAIL=$((FAIL+1)); }

echo ""
echo "════════════════════════════════════════════"
echo "  CIS Ubuntu Level 1 Audit"
echo "  Date: $(date)"
echo "  Host: $(hostname)"
echo "════════════════════════════════════════════"
echo ""

# Section 1 - Filesystem
echo -e "${BLUE}Section 1: Filesystem${NC}"
for fs in cramfs freevxfs jffs2 hfs hfsplus udf; do
  if grep -q "install $fs /bin/true" /etc/modprobe.d/cis-disable-fs.conf 2>/dev/null; then
    ok "Filesystem module disabled: $fs"
  else
    fail "Filesystem module NOT disabled: $fs"
  fi
done

# Section 2 - Services
echo ""
echo -e "${BLUE}Section 2: Services${NC}"
for svc in avahi-daemon cups rpcbind; do
  if systemctl is-enabled "$svc" 2>/dev/null | grep -qE "disabled|not-found"; then
    ok "Service disabled: $svc"
  elif ! systemctl is-active "$svc" 2>/dev/null | grep -q "^active"; then
    ok "Service inactive: $svc"
  else
    fail "Service still running: $svc"
  fi
done

# Section 3 - Network
echo ""
echo -e "${BLUE}Section 3: Network Parameters${NC}"
check_sysctl() {
  local key="$1" expected="$2"
  local actual
  actual=$(sysctl -n "$key" 2>/dev/null || echo "UNKNOWN")
  if [[ "$actual" == "$expected" ]]; then
    ok "sysctl $key = $expected"
  else
    fail "sysctl $key = $actual (expected $expected)"
  fi
}

check_sysctl "net.ipv4.ip_forward" "0"
check_sysctl "net.ipv4.conf.all.send_redirects" "0"
check_sysctl "net.ipv4.conf.all.accept_redirects" "0"
check_sysctl "net.ipv4.conf.all.log_martians" "1"
check_sysctl "net.ipv4.tcp_syncookies" "1"
check_sysctl "kernel.randomize_va_space" "2"
check_sysctl "kernel.dmesg_restrict" "1"
check_sysctl "fs.protected_hardlinks" "1"
check_sysctl "fs.protected_symlinks" "1"

# Section 4 - Auditing
echo ""
echo -e "${BLUE}Section 4: Auditing${NC}"
if systemctl is-active auditd > /dev/null 2>&1; then
  ok "auditd is running"
else
  fail "auditd is NOT running"
fi

if [[ -f "/etc/audit/rules.d/99-cis.rules" ]]; then
  ok "CIS audit rules file exists"
else
  fail "CIS audit rules file missing"
fi

# Section 5 - SSH
echo ""
echo -e "${BLUE}Section 5: SSH Configuration${NC}"
check_ssh() {
  local param="$1" expected="$2"
  local actual
  actual=$(sshd -T 2>/dev/null | grep -i "^${param} " | awk '{print $2}' || echo "UNKNOWN")
  if [[ "$actual" == "$expected" ]]; then
    ok "SSH $param = $expected"
  else
    fail "SSH $param = $actual (expected $expected)"
  fi
}

check_ssh "permitrootlogin" "no"
check_ssh "passwordauthentication" "no"
check_ssh "permitemptypasswords" "no"
check_ssh "x11forwarding" "no"
check_ssh "maxauthtries" "3"

# Section 6 - File Permissions
echo ""
echo -e "${BLUE}Section 6: File Permissions${NC}"
check_perm() {
  local path="$1" expected="$2"
  if [[ -f "$path" ]]; then
    local actual
    actual=$(stat -c %a "$path")
    if [[ "$actual" == "$expected" ]]; then
      ok "Permissions on $path = $expected"
    else
      fail "Permissions on $path = $actual (expected $expected)"
    fi
  fi
}

check_perm "/etc/passwd" "644"
check_perm "/etc/shadow" "640"
check_perm "/etc/group" "644"
check_perm "/etc/gshadow" "640"

# Summary
TOTAL=$((PASS + FAIL))
SCORE=$(awk "BEGIN {printf \"%.1f\", ($PASS/$TOTAL)*100}")

echo ""
echo "════════════════════════════════════════════"
echo -e "  CIS Audit Score: ${GREEN}${SCORE}%${NC}"
echo -e "  ${GREEN}PASS: $PASS${NC}  ${RED}FAIL: $FAIL${NC}  Total: $TOTAL"
echo "════════════════════════════════════════════"

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo -e "${RED}Failed controls need attention!${NC}"
  echo "Run cis-harden.sh to fix them."
fi
