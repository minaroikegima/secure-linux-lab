# Secure Linux Infrastructure Lab

![CI](https://github.com/minaroikegima/secure-linux-lab/actions/workflows/ci.yml/badge.svg)

A Linux system hardening lab aligned with CIS benchmarks, with centralized monitoring, structured logging, and simulated failure scenarios to test infrastructure resilience.

## What This Project Does
- Automatically hardens Linux servers following CIS benchmarks
- Audits and scores server security compliance
- Simulates system failures to test resilience
- Implements centralized monitoring and logging

## Technologies Used
- Linux
- Bash
- Prometheus
- CIS Benchmarks

## Architecture Diagram
```
┌─────────────────────────────────────────────────────┐
│                 Hardened Linux Server                │
│                                                     │
│  ┌─────────────────────────────────────────────┐   │
│  │           Security Controls Layer            │   │
│  │                                             │   │
│  │  ┌──────────┐ ┌──────────┐ ┌────────────┐  │   │
│  │  │   UFW    │ │  Auditd  │ │  Fail2ban  │  │   │
│  │  │Firewall  │ │ Logging  │ │ Protection │  │   │
│  │  └──────────┘ └──────────┘ └────────────┘  │   │
│  └─────────────────────────────────────────────┘   │
│                                                     │
│  ┌─────────────────────────────────────────────┐   │
│  │         Observability Layer                  │   │
│  │                                             │   │
│  │  Node Exporter :9100 → Prometheus → Grafana │   │
│  └─────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘

CIS Benchmark Coverage:
✅ Section 1 - Filesystem Configuration
✅ Section 2 - Disable Unused Services
✅ Section 3 - Network Parameters
✅ Section 4 - Logging and Auditing
✅ Section 5 - SSH Configuration
✅ Section 6 - File Permissions
```

## How to Use

### Run CIS Hardening
```bash
sudo chmod +x hardening/scripts/cis-harden.sh
sudo ./hardening/scripts/cis-harden.sh
```

### Run CIS Audit
```bash
sudo chmod +x hardening/scripts/cis-audit.sh
sudo ./hardening/scripts/cis-audit.sh
```

### Simulate Failures
```bash
sudo chmod +x resilience/chaos/failure-scenarios.sh
sudo ./resilience/chaos/failure-scenarios.sh --scenario=cpu-stress
```

## CIS Benchmark Results
| Section | Controls | Status |
|---------|----------|--------|
| Filesystem | Disable unused modules | ✅ Automated |
| Services | Disable unused services | ✅ Automated |
| Network | Kernel hardening | ✅ Automated |
| Auditing | auditd configuration | ✅ Automated |
| SSH | Secure SSH config | ✅ Automated |
| Permissions | File permissions | ✅ Automated |
