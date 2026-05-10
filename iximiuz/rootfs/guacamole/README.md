# Apache Guacamole Desktop Rootfs

Production-grade Apache Guacamole rootfs for iximiuz playgrounds. Boots
MariaDB → guacd → Tomcat 10 → XRDP → Nginx via systemd with `cloudflared`
pre-installed for instant public access with SSL via Cloudflare Tunnel.

## What It Is

A child image built on top of [`ubuntu-24-04-rootfs`](https://github.com/ibtisam-iq/silver-stack/blob/main/iximiuz/rootfs/ubuntu/README.md).
On first boot, systemd starts `lab-init` → `mariadb` → `tomcat10` → `guacd` → `xrdp` → `nginx` in order.
`lab-init` creates the MariaDB database, imports the Guacamole schema, pre-seeds the RDP connection,
and injects runtime credentials — no manual setup required. Guacamole is accessible on port 80 via Nginx.

## What's Inside

| Component       | Version        | Detail                                              |
|-----------------|----------------|-----------------------------------------------------|
| Base            | `ubuntu-24-04-rootfs` | systemd-enabled Ubuntu 24.04              |
| XFCE4           | Latest apt     | Desktop environment for RDP sessions                |
| XRDP            | Latest apt     | RDP server; `security_layer=rdp` for guacd compat  |
| Firefox         | Latest (Mozilla repo) | Pre-installed browser in desktop session   |
| PipeWire        | Latest apt     | Audio stack for RDP audio forwarding                |
| guacd           | 1.6.0          | Guacamole proxy daemon (built from source)          |
| Tomcat 10       | Latest apt     | Serves guacamole.war (Jakarta EE namespace)         |
| MariaDB         | Latest apt     | Database for Guacamole auth + connections           |
| Nginx           | Latest apt     | Reverse proxy → port 80, WebSocket-aware            |
| cloudflared     | Latest         | Cloudflare Tunnel client                            |

## Directory Structure

```
guacamole/
├── Dockerfile
├── README.md
├── welcome
├── configs/
│   ├── nginx/
│   │   └── guacamole.conf       # Upstream: 127.0.0.1:__GUAC_PORT__; WebSocket support
│   ├── systemd/
│   │   ├── lab-init.service     # oneshot: Before=mariadb,tomcat10,guacd,xrdp,nginx
│   │   └── guacamole.service    # guacd override unit (ordering + HOME env)
│   ├── sudoers.d/
│   │   └── guacamole-user       # Limited sudo for tomcat
│   └── xrdp/
│       └── startwm.sh           # XFCE4 session launcher for XRDP
└── scripts/
    ├── install-desktop.sh       # XFCE4 + TigerVNC + PipeWire + Firefox
    ├── configure-xrdp.sh        # Permissions, security_layer=rdp, .xsession
    ├── install-guacamole.sh     # guacd source build + WAR + JDBC + Connector/J
    ├── configure-guacamole.sh   # guacamole.properties (DB pass placeholder)
    ├── configure-nginx.sh       # Enable guacamole site, remove default
    ├── lab-init.sh              # Boot: MariaDB init, schema, RDP seed, credential inject
    ├── healthcheck.sh           # Build-time validation (12 sections)
    ├── customize-bashrc.sh      # Aliases + welcome banner → ~/.bashrc
    └── install-cloudflared.sh   # Cloudflare Tunnel CLI
```

## Build Arguments

| ARG                      | CI Default       | Description                                               |
|--------------------------|------------------|-----------------------------------------------------------|
| `USER`                   | `ibtisam`        | Interactive non-root user (from base image)               |
| `GUAC_VERSION`           | `1.6.0`          | Guacamole server + client version                         |
| `MYSQL_CONNECTOR_VERSION`| `9.2.0`          | MySQL Connector/J version                                 |
| `GUAC_PORT`              | `8080`           | Tomcat HTTP port — substituted in nginx.conf + welcome    |
| `RDP_USER`               | `musk`        | XRDP desktop username — pre-seeded in DB at build time    |
| `RDP_PORT`               | `3389`           | XRDP listen port                                          |
| `DB_NAME`                | `guacamole_db`   | MariaDB database name                                     |
| `DB_USER`                | `guacamole_user` | MariaDB username                                          |
| `BUILD_DATE`             | CI-injected      | OCI label: image creation timestamp                       |
| `VCS_REF`                | `github.sha`     | OCI label: git commit SHA                                 |

## Runtime Environment Variables

All variables have safe defaults. Override via `docker run -e` or iximiuz env:

| Variable                 | Default (auto-generated if blank) | Description                   |
|--------------------------|-----------------------------------|-------------------------------|
| `DB_PASS`                | `openssl rand` 20 chars           | MariaDB password for DB_USER  |
| `RDP_PASS`               | `openssl rand` 12 chars           | XRDP desktop user password    |
| `DB_NAME`                | `guacamole_db`                    | Override MariaDB database name|
| `DB_USER`                | `guacamole_user`                  | Override MariaDB username      |
| `RDP_USER`               | `musk`                         | Override XRDP desktop user    |
| `RDP_PORT`               | `3389`                            | Override XRDP port            |
| `GUAC_PORT`              | `8080`                            | Override Tomcat port          |

## Boot Sequence

```
systemd (PID 1)
└── lab-init.service [oneshot]
      Generates SSH host keys
      Creates /run/sshd, /run/nginx, /run/xrdp
      Starts temporary MariaDB → creates DB + user (idempotent)
      Imports Guacamole schema (idempotent)
      Pre-seeds XFCE Desktop RDP connection (idempotent)
      Sets RDP_USER password
      Injects DB_PASS into guacamole.properties
      ↓
└── mariadb.service
      ↓
└── tomcat10.service
      Loads guacamole.war + JDBC extension
      ↓
└── guacd.service
      Listens on :4822
      ↓
└── xrdp.service + xrdp-sesman.service
      Listens on :3389 (security_layer=rdp)
      ↓
└── nginx.service
      Listens on :80 → proxies to 127.0.0.1:GUAC_PORT
```

> Guacamole/Tomcat takes **30–60 seconds** to fully initialize on first boot.

## Local Build

```bash
docker build \
  --build-arg USER=ibtisam \
  --build-arg GUAC_VERSION=1.6.0 \
  --build-arg MYSQL_CONNECTOR_VERSION=9.2.0 \
  --build-arg GUAC_PORT=8080 \
  --build-arg RDP_USER=musk \
  --build-arg RDP_PORT=3389 \
  --build-arg DB_NAME=guacamole_db \
  --build-arg DB_USER=guacamole_user \
  -t ghcr.io/ibtisam-iq/guacamole-rootfs:latest \
  .
```

## Usage in an iximiuz Playground

```bash
labctl playground create --base flexbox guacamole-desktop -f guacamole-desktop.yml
```

## Notes

- **`security_layer=rdp`** in `/etc/xrdp/xrdp.ini` is mandatory — guacd's `security=rdp`
  connection parameter requires this to avoid SSL handshake failure.
- **DB password** is never baked into the image — `__DB_PASS__` placeholder is injected
  by `lab-init.sh` at each boot, so credentials are ephemeral per VM.
- **Schema import is idempotent** — safe to reboot without re-importing.
