---
title: Trivy
---

# Trivy

Vulnerability scanner for containers/images. Installs CLI for SBOM and vuln. checks.

--8<-- "includes/common-header.md"
--8<-- "includes/system-requirements.md"

## Installation Command

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/components/trivy-setup.sh | sudo bash
```

## What It Installs

- Trivy CLI (latest).
- Binary in PATH.

## Verify

```bash
trivy version  # e.g., Version: 0.48.x
trivy image alpine:latest  # Test scan
```

--8<-- "includes/post-installation.md"

**Official Docs:** [aquasecurity.github.io/trivy](https://trivy.dev/docs/latest/getting-started/installation/)
