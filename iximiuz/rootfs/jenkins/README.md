# Jenkins LTS Rootfs

Production-grade Jenkins LTS rootfs for iximiuz playgrounds. Boots Jenkins via systemd with Nginx as a reverse proxy and cloudflared pre-installed for instant custom-domain access with SSL via Cloudflare Tunnel. Ships with all CI/CD pipeline tools pre-installed — no manual setup required.

## What It Is

A child image built on top of `ubuntu-24-04-rootfs`. On first boot, systemd starts `lab-init` → `nginx` → `jenkins` in order. Jenkins is accessible immediately on port 80 via Nginx. All pipeline tools (Maven, Node.js, Docker, kubectl, Helm, Terraform, Ansible, etc.) are available system-wide from the first pipeline run.

## What's Inside

### Core

| Component | Version | Detail |
|---|---|---|
| Base | `ubuntu-24-04-rootfs` | systemd-enabled Ubuntu 24.04 |
| Java | OpenJDK 21 | LTS runtime for Jenkins |
| Jenkins | LTS (latest stable) | Runs as `jenkins` system user |
| Nginx | Latest apt | Reverse proxy → port 80 |
| cloudflared | Latest | Cloudflare Tunnel client |

### CI/CD Pipeline Tools

All tools installed via official upstream sources and pinned to verified stable versions as of April 2026.

| Tool | Version | Purpose |
|---|---|---|
| Maven | `3.9.15` | Build Java projects |
| Node.js | `22 LTS` (Jod) | Build Node.js projects |
| npm | `10.x` | Node.js package manager |
| Python | `3.12.3` | Build Python projects |
| Docker | `29.x` (latest) | Build & push container images |
| Trivy | `0.69.3` ⚠️ pinned | CVE scanning — see security note below |
| AWS CLI | `v2` (latest) | ECR, S3, ECS, EKS auth |
| kubectl | `1.35` | Deploy to Kubernetes clusters |
| Helm | `4.1.4` | Deploy Helm charts |
| Terraform | `1.14.x` | Provision infrastructure from pipelines |
| Ansible | `core 2.20` | Deploy to EC2 and bare-metal targets |

> **⚠️ Trivy Security Note:** Trivy `v0.69.4` was a confirmed supply chain attack (CVE-2026-33634, March 19, 2026). The malicious binary exfiltrated secrets from CI/CD pipelines via compromised Aqua Security credentials. This image pins `v0.69.3` — the last verified safe release. Ref: [trivy/discussions/10425](https://github.com/aquasecurity/trivy/discussions/10425)

## Directory Structure

```
jenkins/
├── Dockerfile
├── welcome
├── README.md
├── configs/
│   ├── nginx.conf                  # Upstream: 127.0.0.1:__JENKINS_PORT__
│   ├── jenkins.service             # ExecStart: --httpPort=__JENKINS_PORT__
│   ├── sudoers.d/
│   │   └── jenkins-user
│   └── systemd/
│       └── lab-init.service
└── scripts/
    ├── install-jenkins.sh          # Installs Java 21 + Jenkins LTS
    ├── install-pipeline-tools.sh   # Installs all 10 CI/CD pipeline tools
    ├── configure-nginx.sh          # Enables site, systemd override
    ├── lab-init.sh                 # SSH keys + runtime dir setup
    ├── healthcheck.sh              # Build-time validation (8 sections)
    ├── customize-bashrc.sh         # Aliases → ~/.bashrc
    └── install-cloudflared.sh
```

## Build Arguments

| ARG | Default | Description |
|---|---|---|
| `USER` | ibtisam | Interactive user |
| `JENKINS_PORT` | `8080` | Jenkins HTTP port — substituted in service, nginx, welcome |

## Port Substitution

`__JENKINS_PORT__` is substituted at build time via `sed` in:
- `/etc/nginx/sites-available/jenkins`
- `/etc/systemd/system/jenkins.service`
- `~/.welcome`

## Published Image

```bash
docker pull ghcr.io/ibtisam-iq/jenkins-rootfs:latest
```

## Local Testing

```bash
docker run -d \
  --name jenkins-test \
  --privileged \
  --cgroupns=host \
  -v /sys/fs/cgroup:/sys/fs/cgroup \
  --tmpfs /tmp \
  --tmpfs /run \
  --tmpfs /run/lock \
  -p 8080:80 \
  -p 7022:22 \
  ghcr.io/ibtisam-iq/jenkins-rootfs:latest

# Check services
docker exec jenkins-test systemctl is-active lab-init nginx jenkins

# Get initial admin password
docker exec jenkins-test \
  cat /var/lib/jenkins/.jenkins/secrets/initialAdminPassword

# Verify pipeline tools
docker exec jenkins-test mvn -version
docker exec jenkins-test node --version
docker exec jenkins-test docker --version
docker exec jenkins-test kubectl version --client
docker exec jenkins-test helm version --short
docker exec jenkins-test terraform version
docker exec jenkins-test ansible --version

# Test Nginx reverse proxy
docker exec jenkins-test curl -f http://localhost/health

# Jenkins UI
open http://localhost:8080
```

## Playground

Individual playground manifest: [`iximiuz/manifests/jenkins-server.yml`](../../manifests/jenkins-server.yml)

```bash
labctl playground create --base flexbox jenkins-server -f jenkins-server.yml
```

Part of the full CI/CD stack: [`iximiuz/manifests/ci-cd-stack.yml`](../../manifests/ci-cd-stack.yml)

```bash
labctl playground create --base flexbox ci-cd-stack -f ci-cd-stack.yml
```
