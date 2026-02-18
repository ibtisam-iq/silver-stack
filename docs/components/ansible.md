---
title: Ansible
---

# Ansible

Configuration management tool for automating deployments and orchestration. Installs core Ansible + collections for infra as code.

--8<-- "includes/common-header.md"
--8<-- "includes/system-requirements.md"

## Installation Command

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/components/ansible-setup.sh | sudo bash
```

## What It Installs

- Ansible core (latest stable).
- pip deps (e.g., jinja2).
- Basic collections (core, community.general).

## Verify

```bash
ansible --version  # e.g., ansible [core 2.15.x]
ansible-galaxy collection list  # Installed collections
```

--8<-- "includes/post-installation.md"

**Official Docs:** [docs.ansible.com](https://docs.ansible.com/ansible/latest/index.html)