# Jenkins LTS Rootfs

Production-grade Jenkins LTS rootfs for iximiuz playgrounds. Boots Jenkins via systemd with Nginx as a reverse proxy and cloudflared pre-installed for instant custom-domain access with SSL via Cloudflare Tunnel. Pipeline tools and plugins are **not** pre-installed - they are provided as ready-to-run post-setup scripts to keep the image lean.

## What It Is

A child image built on top of [`ubuntu-24-04-rootfs`](../ubuntu/README.md). On first boot, systemd starts `lab-init` → `nginx` → `jenkins` in order. Jenkins is accessible immediately on port 80 via Nginx.

![](https://github.com/ibtisam-iq/runbook/blob/main/assets/screenshots/jenkins-server-drive-config.png)

> **This is a microVM rootfs for the [iximiuz Labs](https://labs.iximiuz.com) platform.** The platform mounts it as a block device and boots it with its own kernel. systemd becomes PID 1 through the platform boot process. Use `labctl` to create and access the playground - see [Usage](#usage-in-an-iximiuz-playground) below.

Pipeline tools (Maven, Docker, kubectl, etc.) and Jenkins plugins are intentionally **not** baked into the image. Two scripts are placed on `PATH` and can be run after the VM is live - giving full control over what gets installed and keeping the image size minimal.

## What's Inside

### Core

| Component | Version | Detail |
|---|---|---|
| Base | `ubuntu-24-04-rootfs` | systemd-enabled Ubuntu 24.04 |
| Java | OpenJDK 21 | LTS runtime for Jenkins |
| Jenkins | LTS (latest stable) | Runs as `jenkins` system user |
| Nginx | Latest apt | Reverse proxy → port 80 |
| cloudflared | Latest | Cloudflare Tunnel client |

### Post-Setup Scripts (available on PATH)

Two scripts are placed in `/usr/local/bin/` during the build and are callable directly - no path prefix needed. They are **not** run during the build.

#### `install-pipeline-tools`

Installs 10 CI/CD pipeline tools system-wide. Run this **before** your first Jenkins pipeline.

| Tool | Version | Purpose |
|---|---|---|
| Maven | `3.9.15` | Build Java projects |
| Node.js | `22 LTS` (Jod) | Build Node.js projects |
| npm | `10.x` | Node.js package manager |
| Python | `3.12` | Build Python projects |
| Docker | `29.x` (latest) | Build & push container images |
| Trivy | `0.69.3` ⚠️ pinned | CVE scanning - see security note below |
| AWS CLI | `v2` (latest) | ECR, S3, ECS, EKS auth |
| kubectl | `1.35` | Deploy to Kubernetes clusters |
| Helm | `4.1.4` | Deploy Helm charts |
| Terraform | `1.14.x` | Provision infrastructure from pipelines |
| Ansible | `core 2.20` | Deploy to EC2 and bare-metal targets |

> **⚠️ Trivy Security Note:** Trivy `v0.69.4` was a confirmed supply-chain attack (CVE-2026-33634, March 19, 2026). The malicious binary exfiltrated secrets from CI/CD pipelines via compromised Aqua Security credentials. This image pins `v0.69.3` - the last verified safe release. Ref: [trivy/discussions/10425](https://github.com/aquasecurity/trivy/discussions/10425)

```bash
sudo install-pipeline-tools
```

To skip a tool, open the script and comment out the relevant section before running.

#### `install-plugins`

Installs a complete, enterprise-grade set of Jenkins plugins covering the full DevSecOps pipeline lifecycle: SCM, build tools, code quality, security scanning, artifact management, Docker, Kubernetes, notifications, and observability.

Run this **after** Jenkins is fully set up (setup wizard complete + Jenkins URL configured):

```bash
sudo install-plugins
```

The script interactively prompts for your Jenkins URL, username, and password. It downloads `jenkins-cli.jar` fresh, installs all plugins, and triggers a safe restart.

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
│   │   └── jenkins-user            # Allows jenkins daemon to manage its service
│   └── systemd/
│       └── lab-init.service        # oneshot: runs lab-init.sh at each boot
└── scripts/
    ├── install-jenkins.sh          # Installs Java 21 + Jenkins LTS
    ├── install-pipeline-tools.sh   # Post-setup: installs 10 CI/CD tools → /usr/local/bin/
    ├── install-plugins.sh          # Post-setup: installs Jenkins plugins → /usr/local/bin/
    ├── configure-nginx.sh          # Installs nginx, enables site, creates systemd override
    ├── lab-init.sh                 # SSH keys + /run dirs at each boot (oneshot)
    ├── healthcheck.sh              # Build-time validation across 8 sections
    ├── customize-bashrc.sh         # Jenkins/Nginx aliases → ~/.bashrc
    └── install-cloudflared.sh      # Cloudflare Tunnel CLI
```

## Port Substitution

`__JENKINS_PORT__` is a build-time placeholder substituted via `sed` at build time in:

| File | What changes |
|---|---|
| `/etc/nginx/sites-available/jenkins` | `proxy_pass` upstream URL |
| `/etc/systemd/system/jenkins.service` | `--httpPort=` argument |
| `~/.welcome` | Displayed URL |

The CI default is `JENKINS_PORT=8080`. Change it by passing a different `--build-arg JENKINS_PORT=<port>`.

## Build Arguments

| ARG | CI Default | Description |
|---|---|---|
| `USER` | `ibtisam` | Interactive user (inherited from base image) |
| `JENKINS_PORT` | `8080` | Jenkins HTTP port - substituted in service, nginx, welcome |
| `BUILD_DATE` | From `docker/metadata-action` | OCI label: image creation timestamp |
| `VCS_REF` | `github.sha` | OCI label: git commit SHA |

## Local Build

From the `iximiuz/rootfs/jenkins/` directory:

```bash
docker build \
  --build-arg USER="ibtisam" \
  --build-arg JENKINS_PORT=8080 \
  -t ghcr.io/ibtisam-iq/jenkins-rootfs:latest \
  .
```

## Published Image

```bash
docker pull ghcr.io/ibtisam-iq/jenkins-rootfs:latest
```

> **amd64 only.** Built for `linux/amd64` exclusively.

## Usage in an iximiuz Playground

```bash
# Download the manifest
curl -fsSL https://raw.githubusercontent.com/ibtisam-iq/silver-stack/main/iximiuz/manifests/jenkins-server.yml \
  -o jenkins-server.yml

# Create the playground
labctl playground create --base flexbox jenkins-server -f jenkins-server.yml
```

The playground appears under **Playgrounds → My Custom** in the iximiuz Labs dashboard. The **Jenkins UI** tab opens Nginx on port 80 directly.

## First Login

On first boot, welcome page auto-loaded, follow the steps for setup the server.

![](https://github.com/ibtisam-iq/runbook/blob/main/assets/screenshots/jenkins-server-welcome.png)

## Boot Sequence

```
Boot order (systemd):
  lab-init.service  (oneshot)  - generates SSH keys, creates /run/sshd, /run/nginx
       ↓
  nginx.service     (simple)   - starts Nginx reverse proxy on port 80
       ↓
  jenkins.service   (forking)  - starts Jenkins on JENKINS_PORT

Post-boot (manual, user-initiated):
  sudo install-pipeline-tools  - installs Maven, Docker, kubectl, Helm, etc.
       ↓  (after completing Jenkins setup wizard)
  sudo install-plugins         - installs Jenkins plugins via jenkins-cli
```

## Notes

- **Docker daemon is NOT pre-installed** in the image. `install-pipeline-tools` installs Docker as part of the 10 pipeline tools. After installation, the `jenkins` user is added to the `docker` group.
- **Trivy cache directory** (`/var/cache/trivy`) is pre-created and owned by `jenkins` during `install-pipeline-tools` so pipelines can write vulnerability DB caches without permission errors.
- **SSH** is managed by systemd inherited from the base image. Host keys are generated at each boot by `lab-init.sh`.
- **Welcome banner** (`~/.welcome`) has `__JENKINS_PORT__` substituted at build time and is displayed on first interactive login.

## Runbook

Full setup docs and source references, see my runbook:

  https://runbook.ibtisam-iq.com/containers/iximiuz/rootfs/setup-jenkins-rootfs-image

