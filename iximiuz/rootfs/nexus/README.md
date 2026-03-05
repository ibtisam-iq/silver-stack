# Nexus Repository Manager Rootfs

Production-grade Nexus Community Edition rootfs for iximiuz playgrounds. Boots Nexus and Nginx via systemd with cloudflared pre-installed for instant custom-domain access with SSL via Cloudflare Tunnel.

## What It Is

A child image built on top of `ubuntu-24-04-rootfs`. On first boot, systemd starts `lab-init` → `nginx` → `nexus` in order. Nexus requires no external database — it uses its own embedded storage. It is accessible immediately on port 80 via Nginx — no manual setup required.

## What's Inside

| Component | Version | Detail |
|---|---|---|
| Base | `ubuntu-24-04-rootfs` | systemd-enabled Ubuntu 24.04 |
| Java | OpenJDK 21 | LTS runtime (bundled Temurin also available) |
| Nexus | 3.89.1-02 CE | Runs as `nexus` system user |
| Nginx | Latest apt | Reverse proxy → port 80 |
| cloudflared | Latest | Cloudflare Tunnel client |

## Directory Structure

```
nexus/
├── Dockerfile
├── welcome
├── configs/
│   ├── nginx.conf                  # Upstream: 127.0.0.1:__NEXUS_PORT__
│   ├── nexus.service
│   ├── sudoers.d/
│   │   └── nexus-user
│   └── systemd/
│       └── lab-init.service
└── scripts/
    ├── install-nexus.sh            # Java 21 + Nexus OSS (arch-aware)
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
| `NEXUS_PORT` | `8081` | Nexus HTTP port — substituted in service, nginx, welcome |

## Port Substitution

`__NEXUS_PORT__` is substituted at build time via `sed` in:
- `/etc/nginx/sites-available/nexus`
- `/etc/systemd/system/nexus.service`
- `~/.welcome`

## Published Image

```
docker pull ghcr.io/ibtisam-iq/nexus-rootfs:latest
```

## Local Testing

```bash
docker run -d \
  --name nexus-test \
  --privileged \
  --cgroupns=host \
  -v /sys/fs/cgroup:/sys/fs/cgroup \
  --tmpfs /tmp \
  --tmpfs /run \
  --tmpfs /run/lock \
  -p 8081:80 \
  -p 9022:22 \
  ghcr.io/ibtisam-iq/nexus-rootfs:latest

# Check services
docker exec nexus-test systemctl is-active lab-init nginx nexus

# Get initial admin password
docker exec nexus-test \
  cat /opt/sonatype-work/nexus3/admin.password

# Test Nginx reverse proxy
docker exec nexus-test curl -f http://localhost/health

# Nexus UI
open http://localhost:8081
```

## Playground

Individual playground manifest: [`iximiuz/manifests/nexus-server.yml`](../../manifests/nexus-server.yml)

```bash
labctl playground create --base flexbox nexus-server -f nexus-server.yml
```

Part of the full CI/CD stack: [`iximiuz/manifests/ci-cd-stack.yml`](../../manifests/ci-cd-stack.yml)

```bash
labctl playground create --base flexbox ci-cd-stack -f ci-cd-stack.yml
```
