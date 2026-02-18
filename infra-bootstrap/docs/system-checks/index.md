---
title: System Checks Overview
---

# System Checks

Validate your lab environment before bootstrapping. Ensures root access, deps. (curl/bash), internet, supported OS (Ubuntu LTS/Debian derivatives), and arch (x86_64/amd64).

Run preflight early—catches issues upfront.

--8<-- "includes/common-header.md"
--8<-- "includes/system-requirements.md"

## Quick Links

- [Preflight](preflight.md): Full system validation (root, deps, OS, arch).
- [System Info](system-info.md): Resource snapshot (RAM, CPU, hostname).
- [Version Check](version-check.md): Installed package audit.

## Usage Example

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/system-checks/preflight.sh | sudo bash
```

Warnings? Fix and retry. Disposable labs start clean.
