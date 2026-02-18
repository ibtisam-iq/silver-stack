---
title: Jenkins
---

# Jenkins

CI/CD agent for pipelines. Installs core + plugins for builds/testing.

--8<-- "includes/common-header.md"
--8<-- "includes/system-requirements.md"

## Installation Command

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/components/jenkins-setup.sh | sudo bash
```

## What It Installs

- Jenkins core (latest LTS).

## Verify

```bash
java -jar jenkins.war --version  # e.g., Jenkins 2.426.x
sudo systemctl status jenkins  # Active
```

--8<-- "includes/post-installation.md"

**Official Docs:** [jenkins.io/doc/book/installing](https://www.jenkins.io/doc/book/installing/)