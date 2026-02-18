---
title: AWS / EKS Provisioning
---

# AWS / EKS Provisioning

Command-line tool for AWS services. Installs CLI + configures credentials for cloud management.

--8<-- "includes/common-header.md"
--8<-- "includes/system-requirements.md"

## Installation Command

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/components/aws-eks-stack.sh | sudo bash
```

## Options


### Install tools only:

```bash
curl -fsSL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/components/aws-eks-stack.sh | sudo bash
```

### Install + configure AWS automatically:

```bash  
curl -fsSL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/components/aws-eks-stack.sh | sudo bash --auto-config
```

### With custom profile entry:

```bash
curl -fsSL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/components/aws-eks-stack.sh | sudo bash --auto-config --profile
```

## What It Installs

- AWS CLI v2 (latest).
- Basic config (access key, secret, region prompt).

## Verify

```bash
aws --version  # e.g., aws-cli/2.15.x
aws sts get-caller-identity  # Test auth
```

--8<-- "includes/post-installation.md"

**Official Docs:** [docs.aws.amazon.com/cli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)