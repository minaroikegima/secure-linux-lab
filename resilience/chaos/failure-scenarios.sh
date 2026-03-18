#!/usr/bin/env bash
# Chaos Engineering - Simulate infrastructure failures
# Usage: sudo ./failure-scenarios.sh --scenario=<name>
# WARNING: Only run in a test/lab environment!

set -euo pipefail

SCENARIO=""
DURATION=60

for arg in "$@"; do
  case $arg in
    --scenario=*) SCENARIO="${arg#*=}" ;;
    --duration=*) DURATION="${arg#*=}" ;;
  esac
done

[[ $EUID -ne 0 ]] && { echo "ERROR: Run as root"; exit 1; }

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${BLUE}[CHAOS]${NC} $*"; }
ok()   { echo -e "${GREEN}[OK]${NC}    $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }

# Cleanup on exit
cleanup() {
  echo ""
  warn "Cleaning up scenario: $SCENARIO"
  case "$SCENARIO" in
    cpu-stress)      pkill -f stress-ng 2>/dev/null || true ;;
    memory-pressure) pkill -f "stress-ng.*vm" 2>/dev/null || true ;;
    disk-pressure)   rm -f /tmp/chaos-disk-* 2>/dev/null || true ;;
    network-latency) tc qdisc del dev eth0 root 2>/dev/null || true ;;
  esac
  ok "Recovery complete"
}
trap cleanup EXIT INT TERM

# Scenario 1 - CPU Stress
scenario_cpu_stress() {
  log "Scenario: CPU Stress for ${DURATION}s"
  warn "This will spike CPU to trigger alerts"

  if ! command -v stress-ng &>/dev/null; then
    apt-get install -y stress-ng -qq
  fi

  local cores
  cores=$(nproc)
  log "Stressing $cores CPU cores..."
  stress-ng --cpu "$cores" --timeout "${DURATION}s" &

  ok "CPU stress running"
  ok "Expected alert: HighCPUUsage (>85%)"
  log "Monitor with: watch -n1 'mpstat 1 1'"
  wait
}

# Scenario 2 - Memory Pressure
scenario_memory_pressure() {
  log "Scenario: Memory Pressure for ${DURATION}s"
  warn "This will fill 80% of RAM"

  if ! command -v stress-ng &>/dev/null; then
    apt-get install -y stress-ng -qq
  fi

  local total_mb
  total_mb=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
  local fill_mb=$((total_mb * 80 / 100))

  log "Filling ${fill_mb}MB of RAM..."
  stress-ng --vm 1 --vm-bytes "${fill_mb}m" --timeout "${DURATION}s" &

  ok "Memory pressure running"
  ok "Expected alert: HighMemoryUsage (>85%)"
  wait
}

# Scenario 3 - Disk Pressure
scenario_disk_pressure() {
  log "Scenario: Disk Pressure for ${DURATION}s"
  warn "Creating large files in /tmp"

  local tmpfile="/tmp/chaos-disk-$(date +%s)"
  dd if=/dev/zero of="$tmpfile" bs=1M count=500 2>/dev/null
  ok "Created 500MB dummy file"
  ok "Expected alert: DiskSpaceLow (>80%)"
  log "Sleeping ${DURATION}s..."
  sleep "$DURATION"
}

# Scenario 4 - Network Latency
scenario_network_latency() {
  log "Scenario: Network Latency for ${DURATION}s"
  warn "Adding 500ms delay to network traffic"

  tc qdisc add dev eth0 root netem delay 500ms 50ms
  ok "Network latency injected"
  ok "Test with: ping -c 5 8.8.8.8"
  sleep "$DURATION"
}

# List scenarios
list_scenarios() {
  echo ""
  echo "Available scenarios:"
  echo "  --scenario=cpu-stress        Spike CPU usage"
  echo "  --scenario=memory-pressure   Fill RAM"
  echo "  --scenario=disk-pressure     Fill disk space"
  echo "  --scenario=network-latency   Add network delay"
  echo ""
  echo "Options:"
  echo "  --duration=<seconds>         How long to run (default: 60)"
  echo ""
}

# Main
if [[ -z "$SCENARIO" ]]; then
  list_scenarios
  exit 0
fi

echo ""
echo "════════════════════════════════════════════"
echo "  ⚠️  CHAOS ENGINEERING - LAB USE ONLY"
echo "  Scenario: $SCENARIO | Duration: ${DURATION}s"
echo "════════════════════════════════════════════"
echo ""

case "$SCENARIO" in
  cpu-stress)      scenario_cpu_stress ;;
  memory-pressure) scenario_memory_pressure ;;
  disk-pressure)   scenario_disk_pressure ;;
  network-latency) scenario_network_latency ;;
  *) echo "Unknown scenario: $SCENARIO"; list_scenarios; exit 1 ;;
esac
