# SilverStack Dev Machine

A fully provisioned **DevOps workstation** on Ubuntu 24.04 - every tool
pre-installed, every alias pre-wired, zero setup required.

![](__static__/dev-machine-welcome.png)

> This is a pure interactive workstation. No services, no systemd daemons -
> just a clean, fast DevOps environment ready the moment it boots.

## What's pre-installed

| Category | Tools |
|---|---|
| Runtimes | Java 21 · Python 3 · Node.js LTS · Maven |
| Containers | Docker CE · docker-compose · Buildx · Skopeo · dive · hadolint |
| Kubernetes | kubectl · Helm · Kustomize · k9s · kubectx · kubens · stern |
| IaC & CI/CD | Terraform · AWS CLI v2 · Ansible · ansible-lint · pre-commit · yamllint · GitHub CLI |
| Security | Trivy · Gitleaks · cosign · syft |
| Utilities | jq · yq · fzf · ripgrep · nmap · socat · cloudflared |

## Pre-wired shortcuts

```bash
k      # kubectl        d      # docker
tf     # terraform      g      # git
ll la .. ...            ports  myip  paths
```

Tab completion enabled for `kubectl` (`k`) and `docker` (`d`).
Run `alias` to see the full list.

## Networking

No public IP. `cloudflared` is pre-installed - expose any local port to
the internet via Cloudflare Tunnel without firewall rules.

## Resources · 4 vCPU / 10 GiB RAM / 50 GiB disk

## Docs

- GitHub: https://github.com/ibtisam-iq/silver-stack/tree/main/iximiuz/rootfs/dev/machine
- Runbook: https://runbook.ibtisam-iq.com/containers/iximiuz/rootfs/setup-dev-machine-rootfs-image/
- Image: [ghcr.io/ibtisam-iq/dev-machine-rootfs:latest](https://ghcr.io/ibtisam-iq/dev-machine-rootfs:latest)
