# Dev Machine Rootfs

Production-grade DevOps workstation rootfs for iximiuz playgrounds. Boots via Ubuntu 24.04 with the complete SilverStack DevOps toolchain pre-installed - Docker, Kubernetes, Terraform, AWS CLI, security tools, database CLI clients, and more. No setup required.

## What It Is

A child image built on top of [`ubuntu-24-04-rootfs`](../../ubuntu/README.md). Unlike service-based rootfs images ([Jenkins](../../jenkins/README.md), [Nexus](../../nexus/README.md), [SonarQube](../../sonarqube/README.md)), this image does not introduce systemd services of its own - it is a pure interactive DevOps workstation.

> **This is a microVM rootfs for the [iximiuz Labs](https://labs.iximiuz.com) platform.** The platform mounts it as a block device and boots it with its own kernel. systemd becomes PID 1 through the platform boot process. Do not use `docker run` for runtime validation - use `labctl` instead (see [Usage](#usage-in-an-iximiuz-playground) below).

![](https://github.com/ibtisam-iq/runbook/blob/main/assets/screenshots/dev-machine-drive-config.png)

## What's Inside

| Component | Version | Install Method |
|---|---|---|
| Base | `ubuntu-24-04-rootfs` | `FROM` |
| Java | OpenJDK 21 | `apt` |
| Python | 3.x + pip3 + venv | `apt` |
| Node.js | LTS | NodeSource repo |
| Maven | Latest | `apt` |
| Docker | CE (latest) | Official Docker apt repo |
| kubectl | v1.32 | Official Kubernetes apt repo |
| Helm | Latest | Official install script |
| Kustomize | v5.7.1 | GitHub release |
| k9s | v0.50.10 | GitHub release |
| kubectx / kubens | v0.9.5 | GitHub release |
| stern | v1.33.0 | GitHub release |
| eksctl | v0.226.0 | GitHub release |
| Terraform | Latest | HashiCorp apt repo |
| GitHub CLI | Latest | Official GitHub apt repo |
| AWS CLI | v2 (latest) | Official installer |
| Ansible | Latest | `pip3` |
| ansible-lint | Latest | `pip3` |
| pre-commit | Latest | `pip3` |
| yamllint | Latest | `pip3` |
| Skopeo | Latest | `apt` |
| dive | v0.13.1 | GitHub release |
| hadolint | v2.12.0 | GitHub release |
| Trivy | v0.64.1 | Aqua apt repo |
| Gitleaks | v8.28.0 | GitHub release |
| cosign | v3.0.3 | GitHub release |
| syft | v1.26.1 | Official install script |
| jq | v1.8.1 | GitHub release |
| yq | v4.46.1 | GitHub release |
| fzf | v0.65.2 | GitHub release |
| rg (ripgrep) | v14.1.1 | GitHub release |
| nmap | Latest | `apt` |
| socat | Latest | `apt` |
| cloudflared | Latest | Cloudflare apt repo |
| mysql-client | Latest | `apt` |
| postgresql-client | Latest | `apt` |
| sqlite3 | Latest | `apt` |
| redis-tools | Latest | `apt` |
| mongosh | Latest | Official MongoDB apt repo |

## Directory Structure

```
dev/machine/
├── Dockerfile
├── welcome                            # Welcome banner (copied to $HOME/.welcome)
└── scripts/
    ├── install-docker.sh              # Docker CE - official Docker apt repo
    ├── install-tools.sh               # Full DevOps toolchain - 30 phases
    ├── install-cloudflared.sh         # Cloudflare Tunnel CLI
    ├── setup-completions.sh           # System-wide bash + zsh completions
    └── customize-bashrc.sh            # Aliases and helpers → ~/.bashrc
```

> `install-tools-all.sh` is a development/reference script with the full tool catalogue including experimental installs. It is **not** called during the Docker build - `install-tools.sh` is the production installer.

## Tab Completion

Tab completion is installed system-wide under `/etc/bash_completion.d/` for all major CLIs. The short aliases `k` (kubectl) and `d` (docker) are wired to the same completion functions as their full commands:

```bash
k get <TAB>      # identical to: kubectl get <TAB>
d run <TAB>      # identical to: docker run <TAB>
```

## Pre-defined Aliases

| Group | Aliases |
|---|---|
| kubectl | `k` `kgp` `kgs` `kgn` `kgd` `kaf` `kdf` `kdp` `kns` `kctx` `klog` `kexec` |
| docker | `d` `dps` `dpsa` `di` `dex` `dlog` `dprune` `dc` `dcup` `dcdown` `dclogs` |
| terraform | `tf` `tfi` `tfp` `tfa` `tfd` `tfv` `tff` |
| git | `g` `gs` `ga` `gc` `gp` `gl` `gco` `gb` `gd` |
| general | `ll` `la` `..` `...` `ports` `myip` `paths` |

Run `alias` inside the VM to see the full list.

## Networking Note

This playground runs behind NAT - no public IP is assigned to the VM. `cloudflared` is pre-installed to expose local services (e.g., a web app or API) to the public internet via a Cloudflare Tunnel without port forwarding.

## Build Arguments

| ARG | CI Default | Description |
|---|---|---|
| `USER` | `ibtisam` | Non-root interactive user (inherited from base) |
| `BUILD_DATE` | Set by CI metadata-action | OCI label: image creation timestamp |
| `VCS_REF` | `github.sha` | OCI label: git commit SHA |

## Local Build

From the `iximiuz/rootfs/dev/machine/` directory:

```bash
docker build \
  --build-arg USER="ibtisam" \
  -t ghcr.io/ibtisam-iq/dev-machine-rootfs:latest \
  .
```

- `BUILD_DATE` and `VCS_REF` are injected automatically by CI. Local builds do not need them, the OCI labels will be empty, which is acceptable for local testing.
- Do not add `USER root` before `EXPOSE 22`. The image intentionally ends as `USER $USER`, see [Notes](#notes) for the full explanation.

## Published Image

```bash
docker pull ghcr.io/ibtisam-iq/dev-machine-rootfs:latest
```

> **amd64 only.** This image is built for `linux/amd64` exclusively.

## Usage in an iximiuz Playground

### Option 1 - Browser UI

  https://labs.iximiuz.com/playgrounds/SilverStack-dev-machine-e672bcf7

Click **Start** to run immediately, or **Configure** to adjust settings before launching.

> If this URL is unavailable, use Option 2.

### Option 2 - labctl manifest

```bash
# Download the manifest
curl -fsSL https://raw.githubusercontent.com/ibtisam-iq/silver-stack/main/iximiuz/manifests/dev-machine.yml \
  -o dev-machine.yml

# Create the playground
labctl playground create --base flexbox dev-machine -f dev-machine.yml
```

The playground appears under **Playgrounds → My Custom** in the iximiuz Labs dashboard.

![](https://github.com/ibtisam-iq/runbook/blob/main/assets/screenshots/dev-machine-welcome.png)

## Notes

- **Docker daemon** (`docker.service`) is enabled during build and starts automatically when the VM boots via systemd - not during `docker build`.
- **Welcome banner** (`$HOME/.welcome`) is displayed on first interactive login and permanently deleted by `~/.bashrc` logic.
- **SSH** is inherited from the base image. The platform generates host keys at VM boot.
- **`USER $USER` at the end of the Dockerfile is intentional and correct.**
  The Dockerfile ends with `USER $USER` (not `USER root`) for a deliberate reason:
  the `USER` directive only affects what user `docker run` starts the container
  process as. For the `docker run` binary-presence check, running as `ibtisam`
  (not root) correctly validates that all tools are accessible to the non-root
  user. When iximiuz boots the image as a microVM, the platform mounts the
  filesystem as a block device and boots it with its own kernel, systemd becomes
  PID 1 independent of this directive. The `USER` field in the OCI image config
  is completely irrelevant to the microVM boot process.

## Runbook

Full setup docs and source references, see my runbook:

  https://runbook.ibtisam-iq.com/containers/iximiuz/rootfs/setup-dev-machine-rootfs-image
