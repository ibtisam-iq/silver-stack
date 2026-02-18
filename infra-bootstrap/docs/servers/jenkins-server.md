---
title: Jenkins Server
---

# Jenkins Server

Pre-configured CI/CD lab server: One script bootstraps Jenkins + Docker, kubectl/eksctl, Trivy. Ready for pipelines, builds, and K8s testing. Disposable setup—run, test, wipe.

## What It Does

- Runs preflight/system checks.
- Updates OS and installs Jenkins.
- Adds Docker, kubectl/eksctl, Trivy.
- Configures Jenkins user in Docker group.
- Outputs access URLs and initial password.

--8<-- "includes/common-header.md"
--8<-- "includes/system-requirements.md"

## Run It (Direct)

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/servers/Jenkins-Server.sh | sudo bash
```

## Customize (Optional)

Download and edit:

```bash
curl -O https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/servers/Jenkins-Server.sh
chmod +x Jenkins-Server.sh
nano Jenkins-Server.sh  # Add/remove tools (e.g., skip Trivy)
sudo ./Jenkins-Server.sh
```

## What It Installs

- **Jenkins**: Core CI/CD server (port 8080).
- **Docker**: Container runtime (Jenkins user added to group).
- **kubectl + eksctl**: K8s management.
- **Trivy**: Vulnerability scanner.

## Access & Verify

- **URLs**: Local: http://YOUR-IP:8080 | Public: http://PUBLIC-IP:8080 (script outputs both).
- **Initial Password**: Script prints it (use to unlock Jenkins setup).
- **Apply Docker Group**: Run `newgrp docker` after setup.
- **Verify**: `sudo systemctl status jenkins` (running?). Login, create first admin user.

Restart if needed: `sudo systemctl restart jenkins`.