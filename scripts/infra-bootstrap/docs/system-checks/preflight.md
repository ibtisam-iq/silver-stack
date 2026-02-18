---
title: Preflight
---

# Preflight

Initial system validation before bootstrapping. Checks root, deps (curl/bash), internet, OS (Ubuntu/Linux Mint), arch (x86_64/amd64). Fails fast if not ready.

--8<-- "includes/common-header.md"
--8<-- "includes/system-requirements.md"

## Installation Command

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/system-checks/preflight.sh | sudo bash
```

## What It Verifies

- Root privileges.
- curl/bash installed.
- Internet (ping 8.8.8.8).
- OS compatibility.
- Architecture, hardware, virtualization and systemd check.

## Output Example

```
[ OK ]    Supported OS detected: Pop!_OS 24.04 LTS
[ OK ]    Core shell utilities are present.
[INFO]    Checking basic Internet connectivity (ICMP)...
[ OK ]    Internet connectivity verified (ping to 8.8.8.8).
[INFO]    Checking DNS & HTTPS reachability...
[ OK ]    DNS resolution and HTTPS access working (github.com).
[ OK ]    Architecture supported: x86_64
[INFO]    Evaluating hardware capacity...
[ OK ]    Hardware checks completed.
[INFO]    Checking CPU virtualization support flags...
[ OK ]    Virtualization extensions detected (vmx/svm).
[INFO]    Checking init system (systemd)...
[ OK ]    systemd is available – service-based components can be managed.

[ OK ]    Preflight checks completed successfully.
[INFO]    Your system is ready to run infra-bootstrap scripts.
```
