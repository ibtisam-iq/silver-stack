# Jenkins LTS Rootfs

Production-grade Jenkins LTS rootfs for iximiuz playgrounds. Boots Jenkins via systemd with Nginx as a reverse proxy and cloudflared pre-installed for instant custom-domain access with SSL via Cloudflare Tunnel.

## What It Is

A child image built on top of `ubuntu-24-04-rootfs`. On first boot, systemd starts `lab-init` → `nginx` → `jenkins` in order. Jenkins is accessible immediately on port 80 via Nginx — no manual setup required.

## What's Inside

| Component | Version | Detail |
|---|---|---|
| Base | `ubuntu-24-04-rootfs` | systemd-enabled Ubuntu 24.04 |
| Java | OpenJDK 21 | LTS runtime |
| Jenkins | LTS (latest stable) | Runs as `jenkins` system user |
| Nginx | Latest apt | Reverse proxy → port 80 |
| cloudflared | Latest | Cloudflare Tunnel client |

## Directory Structure

```
jenkins/
├── Dockerfile
├── welcome
├── configs/
│   ├── nginx.conf                  # Upstream: 127.0.0.1:__JENKINS_PORT__
│   ├── jenkins.service             # ExecStart: --httpPort=__JENKINS_PORT__
│   ├── sudoers.d/
│   │   └── jenkins-user
│   └── systemd/
│       └── lab-init.service
└── scripts/
    ├── install-jenkins.sh          # Installs Java 21 + Jenkins LTS
    ├── configure-nginx.sh          # Enables site, systemd override
    ├── lab-init.sh                 # SSH keys + runtime dir setup
    ├── healthcheck.sh              # Build-time validation (8 sections)
    ├── customize-bashrc.sh         # Aliases → ~/.bashrc
    └── install-cloudflared.sh
```

## Build Arguments

| ARG | Default | Description |
|---|---|---|
| `USER` | — | Interactive user (default: `ibtisam`) |
| `JENKINS_PORT` | `8080` | Jenkins HTTP port — substituted in service, nginx, welcome |

## Port Substitution

`__JENKINS_PORT__` is substituted at build time via `sed` in:
- `/etc/nginx/sites-available/jenkins`
- `/etc/systemd/system/jenkins.service`
- `~/.welcome`

## Published Image

```
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
