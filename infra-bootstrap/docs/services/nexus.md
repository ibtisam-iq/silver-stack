---
title: Nexus
---

# Nexus

Containerized artifact repository for Maven, Docker, npm. Runs as Docker service—store, proxy, scan packages. Prompt for port on run.

--8<-- "includes/common-header.md"
--8<-- "includes/system-requirements.md"

## Installation Command

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/services/nexus-cont.sh | sudo bash
```

## What It Does

- Runs preflight checks.
- Installs Docker if missing.
- Starts Nexus container (sonatype/nexus3, restart=always).
- Prompts for port (default 8081).

## Access & Verify

- **URLs**: Local: `http://<YOUR-IP>:<PORT>` | Public: `http://<PUBLIC-IP>:<PORT>` (script outputs both).
- **Password**: Script prints admin password (from /nexus-data/admin.password).
- **Verify**: `sudo docker ps | grep nexus` (running?). Access UI, login (admin/password), setup repo.
- **Wait Time**: 2-3 min for full startup.

Official Docs: [help.sonatype.com/repomanager3](https://help.sonatype.com/repomanager3/installation-and-upgrades)
