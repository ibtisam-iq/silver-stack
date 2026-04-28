# Dev Machine Rootfs

Production-grade DevOps workstation rootfs for iximiuz playgrounds. Boots via Ubuntu 24.04 with the complete SilverStack DevOps toolchain pre-installed — Docker, Kubernetes, Terraform, AWS CLI, security tools, and more. No setup required.

## What It Is

A child image built on top of [`ubuntu-24-04-rootfs`](../../ubuntu/README.md). Unlike the service-based rootfs images ([Jenkins](../../jenkins/README.md), [Nexus](../../nexus/README.md), [SonarQube](../../sonarqube/README.md)), this image does not run systemd services — it is a pure developer workstation. The user logs in and every tool is immediately available.

## What's Inside

| Component | Version | Detail |
|---|---|---|
| Base | `ubuntu-24-04-rootfs` | systemd-enabled Ubuntu 24.04 |
| Java | OpenJDK 21 | LTS runtime |
| Python | 3.x (latest apt) | pip3, venv, dev headers |
| Node.js | LTS | via NodeSource repo |
| Maven | Latest apt | Java build tool |
| Docker | CE (latest) | daemon + compose + buildx |
| kubectl | v1.32 | Kubernetes CLI |
| Helm | Latest | Kubernetes package manager |
| Kustomize | v5.7.1 | Kubernetes config management |
| k9s | v0.50.10 | Terminal Kubernetes UI |
| kubectx / kubens | v0.9.5 | Context and namespace switcher |
| stern | v1.33.0 | Multi-pod log tailing |
| Terraform | Latest HashiCorp apt | IaC tool |
| GitHub CLI | Latest | `gh` — GitHub from terminal |
| AWS CLI | v2 (latest) | Official installer |
| Ansible | Latest pip | IT automation |
| ansible-lint | Latest pip | Ansible linter |
| pre-commit | Latest pip | Git hook manager |
| yamllint | Latest pip | YAML linter |
| Skopeo | Latest apt | Container image inspection |
| dive | v0.13.1 | Docker image layer explorer |
| hadolint | v2.12.0 | Dockerfile linter |
| trivy | v0.64.1 | Vulnerability scanner |
| gitleaks | v8.28.0 | Secret scanner |
| cosign | v3.0.3 | Container image signing |
| syft | v1.26.1 | SBOM generator |
| jq | v1.8.1 | JSON processor |
| yq | v4.46.1 | YAML processor |
| fzf | v0.65.2 | Fuzzy finder |
| rg | v14.1.1 | ripgrep — fast search |
| nmap | Latest apt | Network scanner |
| socat | Latest apt | Network relay |
| cloudflared | Latest | Cloudflare Tunnel CLI |

## Directory Structure

```
dev/machine/
├── Dockerfile
├── welcome
└── scripts/
    ├── install-docker.sh           # Docker CE — official Docker apt repo
    ├── install-tools.sh            # All DevOps tools — 27 phases
    ├── install-cloudflared.sh      # Cloudflare Tunnel CLI
    ├── setup-completions.sh        # Bash completions for all CLIs
    └── customize-bashrc.sh         # Aliases → ~/.bashrc
```

## Tab Completion

Tab completion is enabled for all major CLIs via `/etc/bash_completion.d/`. Additionally, the short aliases `k` (kubectl) and `d` (docker) are wired to the same completion functions as their full commands — so pressing Tab after `k` or `d` works exactly like `kubectl` or `docker`.

```bash
k get <TAB>        # same as: kubectl get <TAB>
d run <TAB>        # same as: docker run <TAB>
```

## Networking Note

This playground runs behind NAT — no public IP is assigned to the machine. Access is provided via a Cloudflare Tunnel, which is why `cloudflared` is pre-installed. If you need to expose a local service (e.g., a web app or API) to the public internet from within this lab, use `cloudflared tunnel` to route traffic without requiring port forwarding or a public IP.

## Build Arguments

| ARG | Default | Description |
|---|---|---|
| `USER` | `ibtisam` | Interactive user |
| `BUILD_DATE` | — | OCI label: image creation date |
| `VCS_REF` | — | OCI label: git commit SHA |

## Published Image

```
docker pull ghcr.io/ibtisam-iq/dev-machine-rootfs:latest
```

## Local Testing

```bash
docker run -it --rm \
  --name dev-machine-test \
  -p 7022:22 \
  ghcr.io/ibtisam-iq/dev-machine-rootfs:latest \
  /bin/bash

# Verify tools
docker --version
kubectl version --client
terraform version
aws --version
ansible --version
trivy --version

# Verify aliases
alias | grep -E "^alias (k|d|tf|g)="
```

## Playground

Individual playground manifest: [`iximiuz/manifests/dev-machine.yml`](../../../manifests/dev-machine.yml)

```bash
labctl playground create --base flexbox dev-machine -f dev-machine.yml
```
