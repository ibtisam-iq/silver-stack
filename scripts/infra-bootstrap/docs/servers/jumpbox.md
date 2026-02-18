---
title: Jumpbox
---

# Jumpbox

Bastion/jump server for lab access: One script sets up Terraform, Ansible, kubectl/eksctl, Helm. Gateway for AWS/K8s management—SSH tunnel, CLI tools bundled.

--8<-- "includes/common-header.md"
--8<-- "includes/system-requirements.md"

## Run It (Direct)

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/servers/Jumpbox.sh | sudo bash
```

## Customize (Optional)

Download and edit:

```bash
curl -O https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/servers/Jumpbox.sh
chmod +x Jumpbox.sh
nano Jumpbox.sh  # Add/remove tools (e.g., skip Helm)
sudo ./Jumpbox.sh
```

## What It Installs

- **Preflight & Updates**: System validation + OS refresh.
- **Terraform**: IaC for AWS.
- **Ansible**: Config automation.
- **kubectl + eksctl**: K8s clients.
- **Helm**: K8s package manager.

## Access & Verify

- **Login**: SSH to hostname (default user: ubuntu, pass: infra123).
- **Verify**: `terraform version`, `ansible --version`, `kubectl get nodes`, `helm version`.
- **Tunnel Example**: `ssh -L 8080:k8s:80 ubuntu@jump-ip` (forward ports to cluster).

Ready for AWS/K8s ops. Outputs confirmation on run.
