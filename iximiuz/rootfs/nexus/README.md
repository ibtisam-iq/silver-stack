# Nexus Repository Manager Rootfs

Production-grade Nexus 3 Community Edition rootfs for iximiuz playgrounds. Boots Nexus via systemd with Nginx as a reverse proxy and `cloudflared` pre-installed for instant public access with SSL via Cloudflare Tunnel - no firewall rules needed.

## What It Is

A child image built on top of [`ubuntu-24-04-rootfs`](../ubuntu/README.md). On first boot, systemd starts `lab-init` → `nginx` → `nexus` in order. Nexus uses its own embedded storage under `/opt/sonatype-work` - no external database required. It is accessible immediately on port 80 via Nginx.

> **This is a microVM rootfs for the [iximiuz Labs](https://labs.iximiuz.com) platform.** The platform mounts it as a block device and boots it with its own kernel. systemd becomes PID 1 through the platform boot process. Use `labctl` to create and access the playground - see [Usage](#usage-in-an-iximiuz-playground) below.

![](https://github.com/ibtisam-iq/runbook/blob/main/assets/screenshots/nexus-server-drive-config.png)

## What's Inside

| Component | Version | Detail |
|---|---|---|
| Base | `ubuntu-24-04-rootfs` | systemd-enabled Ubuntu 24.04 |
| Java | OpenJDK 21 | LTS runtime for Nexus |
| Nexus | `3.89.1-02` CE | Runs as `nexus` system user |
| Nginx | Latest apt | Reverse proxy → port 80 |
| cloudflared | Latest | Cloudflare Tunnel client |

## Directory Structure

```
nexus/
├── Dockerfile
├── welcome
├── README.md
├── configs/
│   ├── nginx.conf                  # Upstream: 127.0.0.1:__NEXUS_PORT__
│   ├── nexus.service               # Type=simple; ExecStart: /opt/nexus/bin/nexus run
│   ├── sudoers.d/
│   │   └── nexus-user              # Limited sudo for nexus daemon
│   └── systemd/
│       └── lab-init.service        # oneshot: Before=ssh,nginx,nexus
└── scripts/
    ├── install-nexus.sh            # Java 21 + Nexus CE 3.89.1 (arch-aware)
    ├── configure-nginx.sh          # Installs nginx, enables site, systemd override
    ├── lab-init.sh                 # SSH keys + /run dirs + data dir perms at each boot
    ├── healthcheck.sh              # Build-time validation (8 sections)
    ├── customize-bashrc.sh         # Nexus/Nginx aliases → ~/.bashrc
    └── install-cloudflared.sh      # Cloudflare Tunnel CLI
```

## Port Substitution

`__NEXUS_PORT__` is a build-time placeholder substituted via `sed` in:

| File | What changes |
|---|---|
| `/etc/nginx/sites-available/nexus` | `upstream nexus { server 127.0.0.1:__NEXUS_PORT__ }` |
| `~/.welcome` | Displayed URL in the welcome banner |

Port is configured directly in `/opt/sonatype-work/nexus3/etc/nexus.properties` by `install-nexus.sh`.
The CI default is `NEXUS_PORT=8081`.

## Build Arguments

| ARG | CI Default | Description |
|---|---|---|
| `USER` | `ibtisam` | Interactive non-root user (inherited from base image) |
| `NEXUS_PORT` | `8081` | Nexus HTTP port - substituted in nginx config, nexus.properties, welcome |
| `BUILD_DATE` | From `docker/metadata-action` | OCI label: image creation timestamp |
| `VCS_REF` | `github.sha` | OCI label: git commit SHA |

## Local Build

From the `iximiuz/rootfs/nexus/` directory:

```bash
docker build \
  --build-arg USER="ibtisam" \
  --build-arg NEXUS_PORT=8081 \
  -t ghcr.io/ibtisam-iq/nexus-rootfs:latest \
  .
```

## Local CI Workflow Testing with `act`

The full CI workflow can be run locally using [`act`](https://github.com/nektos/act) — this builds the image through the same pipeline steps that run on GitHub Actions, without pushing to GHCR and without any secrets. From the root of the `silver-stack` repository:

```bash
act push \
  -W .github/workflows/build-nexus-rootfs.yml \
  --no-cache-server
```

The image builds and loads into the local Docker daemon. No GITHUB_TOKEN or GHCR credentials are required.

### Verify the Built Image

```bash
docker images | grep nexus-rootfs
```

## Published Image

The image is built and pushed to GHCR automatically via GitHub Actions on every push to `main`. No manual push is involved.

```bash
docker pull ghcr.io/ibtisam-iq/nexus-rootfs:latest
```

> **amd64 only.** Built for `linux/amd64` exclusively.

## Usage in an iximiuz Playground

### Option 1 - Browser UI

  https://labs.iximiuz.com/playgrounds/SilverStack-nexus-server-9a3f87e9

Click **Start** to run immediately, or **Configure** to adjust settings before launching.

> If this URL is unavailable, use Option 2.

### Option 2 - labctl manifest

```bash
# Download the manifest
curl -fsSL https://raw.githubusercontent.com/ibtisam-iq/silver-stack/main/iximiuz/manifests/nexus-server.yml \
  -o nexus-server.yml

# Create the playground
labctl playground create --base flexbox nexus-server -f nexus-server.yml
```

The playground appears under **Playgrounds → My Custom** in the iximiuz Labs dashboard.

## First Login

On first boot, welcome page auto-loaded, follow the steps for setup the server.

![](https://github.com/ibtisam-iq/runbook/blob/main/assets/screenshots/nexus-server-welcome.png)

## Boot Sequence

```
systemd (PID 1)
  └── lab-init.service  [oneshot]
        Generates SSH host keys
        Creates /run/sshd, /run/nginx
        Fixes /opt/nexus and /opt/sonatype-work ownership
        Creates /opt/sonatype-work/jvm-prefs
          ↓
  └── nginx.service     [simple, daemon off]
        Listens on :80 → proxies to 127.0.0.1:NEXUS_PORT
          ↓
  └── nexus.service     [simple]
        /opt/nexus/bin/nexus run (as nexus:nexus)
```

## Notes

- **SSH** is managed by systemd inherited from the base image. Host keys are generated at each boot by `lab-init.sh`.
- **Welcome banner** (`~/.welcome`) has `__NEXUS_PORT__` substituted at build time and is displayed on first interactive login.

## Runbook

Full setup docs and source references, see my runbook:

  https://runbook.ibtisam-iq.com/containers/iximiuz/rootfs/setup-nexus-rootfs-image
