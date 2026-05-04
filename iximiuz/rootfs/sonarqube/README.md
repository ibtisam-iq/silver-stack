# SonarQube Community Edition Rootfs

Production-grade SonarQube LTA rootfs for iximiuz playgrounds. Boots PostgreSQL, SonarQube, and Nginx via systemd with `cloudflared` pre-installed for instant public access with SSL via Cloudflare Tunnel - no firewall rules needed.

## What It Is

A child image built on top of [`ubuntu-24-04-rootfs`](../ubuntu/README.md). On first boot, systemd starts `lab-init` → `postgresql` → `nginx` → `sonarqube` in order. The `lab-init` oneshot creates the PostgreSQL role and database before SonarQube starts - no manual database setup required. SonarQube is accessible immediately on port 80 via Nginx.

> **This is a microVM rootfs for the [iximiuz Labs](https://labs.iximiuz.com) platform.** The platform mounts it as a block device and boots it with its own kernel. systemd becomes PID 1 through the platform boot process. Use `labctl` to create and access the playground - see [Usage](#usage-in-an-iximiuz-playground) below.

![](https://github.com/ibtisam-iq/runbook/blob/main/assets/screenshots/sonarqube-server-drive-config.png)

## What's Inside

| Component | Version | Detail |
|---|---|---|
| Base | `ubuntu-24-04-rootfs` | systemd-enabled Ubuntu 24.04 |
| Java | OpenJDK 21 | Required by SonarQube and its embedded Elasticsearch |
| PostgreSQL | 18 (PGDG) | External database for SonarQube; runs as `postgres` system user |
| SonarQube | `26.2.0.119303` CE (LTA) | Runs as `sonar` system user |
| Nginx | Latest apt | Reverse proxy → port 80 |
| cloudflared | Latest | Cloudflare Tunnel client |

## Directory Structure

```
sonarqube/
├── Dockerfile
├── README.md
├── welcome
├── configs/
│   ├── nginx.conf                  # Upstream: 127.0.0.1:__SONARQUBE_PORT__
│   ├── sonarqube.service           # Type=simple; ExecStart: sonar.sh console
│   ├── sonar.properties            # DB, web server, Elasticsearch, CE JVM opts
│   ├── sudoers.d/
│   │   └── sonarqube-user          # Limited sudo for sonar daemon
│   └── systemd/
│       └── lab-init.service        # oneshot: Before=ssh,postgresql,nginx,sonarqube
└── scripts/
    ├── install-postgresql.sh       # PG18 via official PGDG apt repo
    ├── install-sonarqube.sh        # Java 21 + SonarQube LTA 26.2 + sonar user + ES limits
    ├── configure-nginx.sh          # Installs nginx, enables site, systemd override
    ├── lab-init.sh                 # SSH keys + PostgreSQL DB init + sysctl at each boot
    ├── healthcheck.sh              # Build-time validation (10 sections)
    ├── customize-bashrc.sh         # SonarQube/PostgreSQL/Nginx aliases → ~/.bashrc
    └── install-cloudflared.sh      # Cloudflare Tunnel CLI
```

## Port Substitution

`__SONARQUBE_PORT__` is a build-time placeholder substituted via `sed` in:

| File | What changes |
|---|---|
| `/opt/sonarqube/conf/sonar.properties` | `sonar.web.port=__SONARQUBE_PORT__` |
| `/etc/nginx/sites-available/sonarqube` | `upstream sonarqube { server 127.0.0.1:__SONARQUBE_PORT__ }` |
| `~/.welcome` | Displayed URL in the welcome banner |

The CI default is `SONARQUBE_PORT=9000`. Elasticsearch uses port `9001` (internal only, not substituted).

## Build Arguments

| ARG | CI Default | Description |
|---|---|---|
| `USER` | `ibtisam` | Interactive non-root user (inherited from base image) |
| `SONARQUBE_PORT` | `9000` | SonarQube HTTP port - substituted in sonar.properties, nginx, welcome |
| `BUILD_DATE` | From `docker/metadata-action` | OCI label: image creation timestamp |
| `VCS_REF` | `github.sha` | OCI label: git commit SHA |

## Runtime Initialization (`lab-init.sh`)

Runs once per boot as a systemd `oneshot` **before** SSH, PostgreSQL, Nginx, and SonarQube start:

- Generates SSH host keys (ephemeral per VM)
- Creates `/run/sshd`, `/run/nginx`, `/run/postgresql`
- Starts the PostgreSQL cluster via `pg_ctlcluster 18 main start`
- Idempotently creates the `sonar` role (`sonar_password`) and `sonarqube` database
- Grants all privileges on the database to the `sonar` role
- Fixes `/opt/sonarqube` ownership to `sonar:sonar`
- Applies `vm.max_map_count=524288` and `fs.file-max=131072` via `sysctl` (required by the embedded Elasticsearch)

## Local Build

From the `iximiuz/rootfs/sonarqube/` directory:

```bash
docker build \
  --build-arg USER="ibtisam" \
  --build-arg SONARQUBE_PORT=9000 \
  -t ghcr.io/ibtisam-iq/sonarqube-rootfs:latest \
  .
```

## Published Image

```bash
docker pull ghcr.io/ibtisam-iq/sonarqube-rootfs:latest
```

> **amd64 only.** Built for `linux/amd64` exclusively.

## Usage in an iximiuz Playground

```bash
# Download the manifest
curl -fsSL https://raw.githubusercontent.com/ibtisam-iq/silver-stack/main/iximiuz/manifests/sonarqube-server.yml \
  -o sonarqube-server.yml

# Create the playground (requires 4 vCPU / 10 GiB RAM)
labctl playground create --base flexbox sonarqube-server -f sonarqube-server.yml
```

The playground appears under **Playgrounds → My Custom** in the iximiuz Labs dashboard.

## First Login

On first boot, welcome page auto-loaded, follow the steps for setup the server.

![](https://github.com/ibtisam-iq/runbook/blob/main/assets/screenshots/sonarqube-server-welcome.png)

## Boot Sequence

```
systemd (PID 1)
  └── lab-init.service  [oneshot]
        Generates SSH host keys
        Creates /run/sshd, /run/nginx, /run/postgresql
        Starts PostgreSQL cluster (pg_ctlcluster 18 main start)
        Creates sonar role + sonarqube database (idempotent)
        Applies vm.max_map_count and fs.file-max
          ↓
  └── postgresql.service
        Managed by pg_ctlcluster; Ubuntu systemd unit is a wrapper
          ↓
  └── nginx.service     [simple, daemon off]
        Listens on :80 → proxies to 127.0.0.1:SONARQUBE_PORT
          ↓
  └── sonarqube.service [simple]
        /opt/sonarqube/bin/linux-x86-64/sonar.sh console (as sonar:sonar)
        Requires=postgresql.service lab-init.service
```

> SonarQube takes **60–120 seconds** to fully initialize on first boot. Elasticsearch startup is the longest phase.

## Notes

- **SSH** is managed by systemd inherited from the base image. Host keys are generated at each boot by `lab-init.sh`.
- **Welcome banner** (`~/.welcome`) has `__SONARQUBE_PORT__` substituted at build time and is displayed on first interactive login.

## Runbook

Full setup docs and source references, see my runbook:

  https://runbook.ibtisam-iq.com/containers/iximiuz/rootfs/setup-sonarqube-rootfs-image
