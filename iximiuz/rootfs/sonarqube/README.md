# SonarQube Community Edition Rootfs

Production-grade SonarQube LTA rootfs for iximiuz playgrounds. Boots PostgreSQL, SonarQube, and Nginx via systemd with cloudflared pre-installed for instant custom-domain access with SSL via Cloudflare Tunnel.

## What It Is

A child image built on top of `ubuntu-24-04-rootfs`. On first boot, systemd starts `lab-init` → `postgresql` → `nginx` → `sonarqube` in order. The PostgreSQL role and database are created at runtime by `lab-init.sh`. SonarQube is accessible immediately on port 80 via Nginx — no manual setup required.

## What's Inside

| Component | Version | Detail |
|---|---|---|
| Base | `ubuntu-24-04-rootfs` | systemd-enabled Ubuntu 24.04 |
| Java | OpenJDK 21 | LTS runtime |
| PostgreSQL | 18 (PGDG) | Runs as `postgres` system user |
| SonarQube | 26.2 Community Edition (LTA) | Runs as `sonar` system user |
| Nginx | Latest apt | Reverse proxy → port 80 |
| cloudflared | Latest | Cloudflare Tunnel client |

## Directory Structure

```
sonarqube/
├── Dockerfile
├── welcome
├── configs/
│   ├── nginx.conf                  # Upstream: 127.0.0.1:__SONARQUBE_PORT__
│   ├── sonarqube.service
│   ├── sonar.properties            # DB + web + ES + CE JVM options
│   ├── sudoers.d/
│   │   └── sonarqube-user
│   └── systemd/
│       └── lab-init.service
└── scripts/
    ├── install-postgresql.sh       # PG18 via PGDG apt repo
    ├── install-sonarqube.sh        # SonarQube LTA + sonar user
    ├── configure-nginx.sh          # Enables site, systemd override
    ├── lab-init.sh                 # SSH keys + DB init + sysctl
    ├── healthcheck.sh              # Build-time validation
    ├── customize-bashrc.sh         # Aliases → ~/.bashrc
    └── install-cloudflared.sh
```

## Build Arguments

| ARG | Default | Description |
|---|---|---|
| `USER` | — | Interactive user (default: `ibtisam`) |
| `SONARQUBE_PORT` | `9000` | SonarQube HTTP port — substituted in sonar.properties, nginx, welcome |

## Port Substitution

`__SONARQUBE_PORT__` is substituted at build time via `sed` in:
- `/opt/sonarqube/conf/sonar.properties`
- `/etc/nginx/sites-available/sonarqube`
- `~/.welcome`

## Runtime Initialization (`lab-init.sh`)

Runs once per boot as a systemd `oneshot` before all other services:
- Generates SSH host keys
- Creates PostgreSQL role `sonar` and database `sonarqube`
- Applies `vm.max_map_count=524288` and `fs.file-max=131072` (required by Elasticsearch)

## Published Image

```
docker pull ghcr.io/ibtisam-iq/sonarqube-rootfs:latest
```

## Local Testing

```bash
docker run -d \
  --name sonarqube-test \
  --privileged \
  --cgroupns=host \
  -v /sys/fs/cgroup:/sys/fs/cgroup \
  --tmpfs /tmp \
  --tmpfs /run \
  --tmpfs /run/lock \
  -p 9000:80 \
  -p 8022:22 \
  ghcr.io/ibtisam-iq/sonarqube-rootfs:latest

# Check services (wait ~30s for SonarQube to fully start)
docker exec sonarqube-test systemctl is-active lab-init postgresql nginx sonarqube

# Test PostgreSQL
docker exec sonarqube-test su - postgres -c "psql -c '\l'"

# Check health
docker exec sonarqube-test \
  curl -u admin:admin http://localhost:9000/api/system/health

# Test Nginx reverse proxy
docker exec sonarqube-test curl -f http://localhost/health

# SonarQube UI (default credentials: admin / admin)
open http://localhost:9000
```

## Playground

Individual playground manifest: [`iximiuz/manifests/sonarqube-server.yml`](../../manifests/sonarqube-server.yml)

```bash
labctl playground create --base flexbox sonarqube-server -f sonarqube-server.yml
```

Part of the full CI/CD stack: [`iximiuz/manifests/ci-cd-stack.yml`](../../manifests/ci-cd-stack.yml)

```bash
labctl playground create --base flexbox ci-cd-stack -f ci-cd-stack.yml
```
