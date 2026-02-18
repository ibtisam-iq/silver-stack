---
title: Containerd
---

# Containerd

Lightweight container runtime for K8s/CRI. Installs daemon + config for efficient pod management.

--8<-- "includes/common-header.md"
--8<-- "includes/system-requirements.md"

## Installation Command

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/kubernetes/containerd-setup.sh | sudo bash
```

## What It Installs

- Containerd (latest stable).
- systemd service (auto-start).
- Basic config (/etc/containerd/config.toml).

## Verify

```bash
ctr version  # e.g., containerd github.com/containerd/containerd v1.7.x
systemctl status containerd  # Active (running)
```

--8<-- "includes/post-installation.md"

**Official Docs:** [containerd.io/docs](https://containerd.io/docs/getting-started/)
