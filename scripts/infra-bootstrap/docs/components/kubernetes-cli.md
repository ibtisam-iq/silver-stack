---
title: kubectl + helm + kustomize + k9s
---

# kubectl + helm + kustomize + k9s

K8s CLI tools: kubectl for commands, eksctl for EKS clusters. Installs both for AWS K8s management.

--8<-- "includes/common-header.md"
--8<-- "includes/system-requirements.md"

## Installation Command

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/components/kubernetes-cli.sh | sudo bash
```

## What It Installs

- kubectl (latest stable).
- eksctl (latest).

## Verify

```bash
kubectl version --client  # e.g., Client Version: v1.34.x
eksctl version  # e.g., 0.174.x
```

--8<-- "includes/post-installation.md"

**Official Docs:** [kubernetes.io/docs/reference/kubectl](https://kubernetes.io/docs/reference/kubectl/) | [eksctl.io](https://eksctl.io/usage/)