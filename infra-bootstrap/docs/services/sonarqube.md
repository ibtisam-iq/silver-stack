---
title: SonarQube
---

# SonarQube

Containerized code quality & security scanner (with Postgres backend). Runs as Docker service—scan repos, enforce standards. Prompt for port on run.

--8<-- "includes/common-header.md"
--8<-- "includes/system-requirements.md"

## Installation Command

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/services/sonarqube-cont.sh | sudo bash
```

## What It Does

- Runs preflight checks.
- Installs Docker if missing.
- Starts SonarQube LTS (sonatype/sonarqube:lts-community, restart=always).
- Prompts for port (default 9000).
- Disables ES bootstrap checks for quick start.

## Access & Verify

- **URLs**: Local: `http://<YOUR-IP>:<PORT>` | Public: `http://<PUBLIC-IP>:<PORT>` (script outputs both).
- **Credentials**: admin/admin (change after login).
- **Verify**: `sudo docker ps | grep sonarqube` (running?). Access UI, run first scan.
- **Wait Time**: 2-3 min for full startup.

Official Docs: [docs.sonarsource.com/sonarqube](https://docs.sonarsource.com/sonarqube/latest/setup-and-upgrade/install-the-server/)
