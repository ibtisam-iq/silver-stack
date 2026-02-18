---
title: Version Check
---

# Version Check

Audits installed DevOps tools. Runs preflight, lists versions (Ansible, AWS CLI, Docker, Containerd, Runc, Git, Python, Node.js, npm, Helm, Jenkins, kubectl, eksctl, Terraform).

--8<-- "includes/common-header.md"
--8<-- "includes/system-requirements.md"

## Installation Command

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/system-checks/version-check.sh | sudo bash
```

## What It Verifies

- Tool presence + versions.
- Preflight first.

## Output Example

```
╔════════════════════════════════════════════════════════╗
║ infra-bootstrap — Installed Tools & Versions
╚════════════════════════════════════════════════════════╝

[INFO]    Preflight check running...
[ OK ]    Preflight passed!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[INFO]    Programming Languages
 • python3:        3.12.3
 • go:             [ NOT INSTALLED ]
 • node:           [ NOT INSTALLED ]
 • ruby:           [ NOT INSTALLED ]
 • rust:           [ NOT INSTALLED ]
 • java:           [ NOT INSTALLED ]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[INFO]    DevOps & Infrastructure
 • docker:         29.1.2
 • containerd:     v2.2.0
 • runc:           1.3.4
 • ansible:        [ NOT INSTALLED ]
 • terraform:      [ NOT INSTALLED ]
 • packer:         [ NOT INSTALLED ]
 • vagrant:        [ NOT INSTALLED ]
 • podman:         [ NOT INSTALLED ]
 • buildah:        [ NOT INSTALLED ]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[INFO]    Kubernetes Stack
 • kubectl:        1.34.2
 • k9s:            [ NOT INSTALLED ]
 • helm:           [ NOT INSTALLED ]
 • eksctl:         [ NOT INSTALLED ]
 • kind:           [ NOT INSTALLED ]
 • crictl:         [ NOT INSTALLED ]
 • etcdctl:        [ NOT INSTALLED ]
 • kustomize:      [ NOT INSTALLED ]
 • minikube:       [ NOT INSTALLED ]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[INFO]    Cloud Providers
 • aws:            [ NOT INSTALLED ]
 • gcloud:         [ NOT INSTALLED ]
 • doctl:          [ NOT INSTALLED ]
 • azure:          [ NOT INSTALLED ]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[INFO]    Security / DevSecOps
 • trivy:          [ NOT INSTALLED ]
 • vault:          [ NOT INSTALLED ]
 • lynis:          [ NOT INSTALLED ]
 • falco:          [ NOT INSTALLED ]
 • bandit:         [ NOT INSTALLED ]
 • snyk:           [ NOT INSTALLED ]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[INFO]    Build & Test Chain
 • npm:            [ NOT INSTALLED ]
 • pip:            [ NOT INSTALLED ]
 • pip3:           [ NOT INSTALLED ]
 • make:           4.3
 • gcc:            13.3.0
 • g++:            [ NOT INSTALLED ]
 • cmake:          [ NOT INSTALLED ]
 • pytest:         [ NOT INSTALLED ]
 • maven:          [ NOT INSTALLED ]
 • gradle:         [ NOT INSTALLED ]
 • mkdocs:         [ NOT INSTALLED ]
 • shellcheck:     [ NOT INSTALLED ]
 • yamllint:       [ NOT INSTALLED ]
 • golangci-lint:  [ NOT INSTALLED ]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[INFO]    Network Utility Availability
 • dig:            Missing
 • nslookup:       Missing
 • traceroute:     Missing
 • netcat:         Available
 • nc:             Available
 • iperf3:         Missing
 • nmap:           Missing
 • curl:           Available
 • wget:           Available
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[ OK ]    Version scan complete
```

Use for audits—outputs to console.
