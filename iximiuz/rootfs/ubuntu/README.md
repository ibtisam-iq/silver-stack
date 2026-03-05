# Ubuntu 24.04 Rootfs

Base image for all SilverStack iximiuz playground machines. Every other rootfs in this stack builds `FROM` this image.

## What It Is

A fully unminimized, systemd-enabled Ubuntu 24.04 image with SSH, a curated DevOps toolset, and per-user shell customizations pre-baked. It is not a service image — it has no application installed. Its sole job is to be a solid, consistent base for all child images.

## What's Inside

| Layer | Detail |
|---|---|
| Base | `ubuntu:24.04` — fully unminimized via `unminimize` |
| Init system | `systemd` as PID 1 |
| SSH | Key-based auth only, password auth disabled |
| Shell | Bash with fzf, vim, custom prompt, git config |
| User | `root` + configurable `$USER` (default: `ibtisam`) |

**Pre-installed tools:**

| Tool | Purpose |
|---|---|
| `arkade` | DevOps package installer |
| `jq` / `yq` / `fx` | JSON and YAML processors |
| `task` / `just` | Command runners |
| `fzf` / `ripgrep` | Fuzzy finder and fast grep |
| `btop` | Resource monitor |
| `cfssl` | Cloudflare TLS toolkit |
| `code-server` | VS Code in the browser |
| `websocat` | WebSocket client |

## Directory Structure

```
ubuntu/
├── Dockerfile
├── welcome
├── configs/
│   └── profile.d/
│       └── 00-prompt.sh       # System-wide PS1 prompt
└── scripts/
    ├── add-user.sh
    ├── customize-bashrc.sh
    ├── customize-git.sh
    ├── customize-vimrc.sh
    ├── get-arkade.sh
    ├── get-btop.sh
    ├── get-cfssl.sh
    ├── get-code-server.sh
    ├── get-common-tools.sh
    ├── get-fzf.sh
    ├── get-websocat.sh
    └── set-up-systemd-examiner-service.sh
```

## Build Arguments

| ARG | Default | Description |
|---|---|---|
| `USER` | ibtisam | Non-root interactive user to create |
| `BTOP_VERSION` | 1.4.4 | btop release version |
| `CFSSL_VERSION` | 1.6.5 | cfssl release version |
| `WEBSOCAT_VERSION` | 1.14.1 | websocat release version |
| `ARKADE_BIN_DIR` | /usr/local/bin | Installation path for arkade |

## Published Image

```
docker pull ghcr.io/ibtisam-iq/ubuntu-24-04-rootfs:latest
```

## Playground

Individual playground manifest: [`iximiuz/manifests/dev-machine.yml`](../../manifests/dev-machine.yml)

```bash
labctl playground create --base flexbox dev-machine -f dev-machine.yml
```
