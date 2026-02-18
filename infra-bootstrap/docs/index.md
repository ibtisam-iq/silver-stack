---
title: Home
---

# Infra Bootstrap

Welcome to **Infra Bootstrap**—your one-stop Bash framework for spinning up DevOps tools and Kubernetes labs in disposable environments. Modular scripts for fast, repeatable setups: From system checks to full clusters.

No bloat. No deps. Just `curl | bash` and run.

--8<-- "includes/common-header.md"
--8<-- "includes/system-requirements.md"

## Quick Start

Clone and bootstrap:

```bash
# Check system
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/system-checks/preflight.sh | sudo bash  
```

## Sections Overview

- [System Checks](system-checks/index.md): Validate your environment first.
- [Kubernetes](kubernetes/index.md): Self-managed clusters, CNI, addons.
- [Server Builds](servers/index.md): Pre-configured labs like Jenkins, Jumpbox.
- [Components](components/index.md): Standalone binaries (Docker, Terraform, etc.).
- [Services](services/index.md): Containerized tools (SonarQube, Nexus etc. via Docker Compose).

*Built for labs, not production. Harden as needed.*
