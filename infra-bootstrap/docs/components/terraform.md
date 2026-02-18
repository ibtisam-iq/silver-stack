---
title: Terraform
---

# Terraform

IaC tool for provisioning infra. Installs CLI + providers for AWS/Azure/GCP.

--8<-- "includes/common-header.md"
--8<-- "includes/system-requirements.md"

## Installation Command

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/components/terraform-setup.sh | sudo bash
```

## What It Installs

- Terraform (latest stable).

## Verify

```bash
terraform version  # e.g., Terraform v1.6.x
terraform init  # Test in empty dir
```

--8<-- "includes/post-installation.md"

**Official Docs:** [developer.hashicorp.com/terraform/install](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
