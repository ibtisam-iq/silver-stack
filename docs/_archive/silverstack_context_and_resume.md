# SilverStack — Context Document & Resume Bullets

## What This Is

This document captures the full context of the SilverStack project —
what was built, how it works, and what skills it demonstrates.
It serves two purposes:
1. **LLM context** — paste this into any AI tool to give it instant understanding of the work
2. **Resume bullets** — ready-to-use achievement statements extracted from actual work done

---

## Project Context (for LLM Onboarding)

### What is SilverStack?

SilverStack is a production-grade, self-hosted CI/CD platform built for the
**iximiuz Labs** microVM playground environment. It consists of five custom
rootfs (root filesystem) images, each published to GHCR and bootable as a
microVM via the iximiuz platform.

### The Platform: iximiuz Labs

- iximiuz Labs is a browser-based lab platform where playgrounds run as **microVMs** — not Docker containers.
- Each rootfs image is mounted as a **block device**, booted with its own kernel. **systemd becomes PID 1** through the platform boot process.
- The `USER` directive in a Dockerfile only affects `docker run` — it has **zero effect** on microVM boot. The platform boots as root regardless.
- Validation is done via `labctl` (the iximiuz CLI), not `docker run`.
- `docker run` is valid only for binary-presence checks — not for service or systemd validation.

### The Five Images

| Image | GHCR | Role |
|---|---|---|
| `ubuntu-24-04-rootfs` | `ghcr.io/ibtisam-iq/ubuntu-24-04-rootfs:latest` | Base image — systemd, SSH, non-root user, base tools |
| `dev-machine-rootfs` | `ghcr.io/ibtisam-iq/dev-machine-rootfs:latest` | Standalone DevOps workstation |
| `dev-cicd-rootfs` | `ghcr.io/ibtisam-iq/dev-cicd-rootfs:latest` | Minimal jump host for CI/CD stack |
| `jenkins-rootfs` | `ghcr.io/ibtisam-iq/jenkins-rootfs:latest` | Jenkins LTS + Nginx + cloudflared |
| `sonarqube-rootfs` | `ghcr.io/ibtisam-iq/sonarqube-rootfs:latest` | SonarQube 26.2 CE + PostgreSQL 18 + Nginx + cloudflared |
| `nexus-rootfs` | `ghcr.io/ibtisam-iq/nexus-rootfs:latest` | Nexus 3.89.1 CE + Nginx + cloudflared |

### The Stack Topology (CI/CD Stack)

All four nodes run in a single **Flexbox playground** sharing a private network (`172.16.0.0/24`).
Total budget: 10 vCPU, 16 GiB RAM, 150 GiB disk.

| Node | Image | CPU | RAM | Disk | Role |
|---|---|---|---|---|---|
| `dev-machine` | `dev-cicd-rootfs` | 1 vCPU | 1 GiB | 30 GiB | Jump host / workstation |
| `jenkins-server` | `jenkins-rootfs` | 3 vCPU | 4 GiB | 40 GiB | CI/CD orchestrator |
| `sonarqube-server` | `sonarqube-rootfs` | 3 vCPU | 6 GiB | 40 GiB | Code quality + DB |
| `nexus-server` | `nexus-rootfs` | 3 vCPU | 5 GiB | 40 GiB | Artifact registry |

### Service Architecture (per node)

Every service node follows the same pattern:
- **`lab-init`** (oneshot) → generates SSH keys, creates `/run` dirs, fixes ownership
- **Nginx** (port 80) → reverse proxy to the service internal port
- **Service daemon** → runs as a dedicated system user (`jenkins`, `sonar`, `nexus`)
- **`cloudflared`** → pre-installed for custom-domain SSL access without firewall rules

Boot order enforced via systemd `Before=` / `After=` constraints.

### Key Technical Decisions Documented

1. **`USER $USER` at end of Dockerfile is intentional** — `docker run` starts as the non-root user for binary validation; microVM boot ignores this directive entirely.
2. **`install-tools.sh` uses COPY not bind mount** — it runs `rm -rf /tmp/*` in final cleanup; a bind mount would delete a live mountpoint.
3. **`lab-init` runs before all services at every boot** — SSH keys are ephemeral, `/run` dirs are wiped by tmpfs, and service data ownership must be re-confirmed on each fresh microVM mount.
4. **Jenkins pipeline tools are not baked in** — two post-setup scripts (`install-pipeline-tools`, `install-plugins`) are on PATH, run by the user after boot, keeping the image lean.
5. **PostgreSQL is provisioned at runtime, not build time** — `lab-init.sh` creates the `sonar` role and `sonarqube` database idempotently at each boot.
6. **Build-time port placeholders** (`__NEXUS_PORT__`, `__SONARQUBE_PORT__`, `__JENKINS_PORT__`) substituted via `sed` — port configured once at build, never needs manual editing at runtime.

### Source Repository

`github.com/ibtisam-iq/silver-stack`

```
iximiuz/
├── manifests/
│   ├── cicd-stack.yml
│   ├── dev-machine.yml
│   ├── jenkins-server.yml
│   ├── sonarqube-server.yml
│   └── nexus-server.yml
└── rootfs/
    ├── ubuntu/
    ├── dev/
    │   ├── machine/    ← standalone dev workstation
    │   └── ci-cd/      ← jump host for stack
    ├── jenkins/
    ├── sonarqube/
    └── nexus/
```

### Live Playground URLs

| Playground | URL |
|---|---|
| CI/CD Stack | https://labs.iximiuz.com/playgrounds/SilverStack-CICD-Stack-1766a8a1 |
| Jenkins | https://labs.iximiuz.com/playgrounds/SilverStack-jenkins-server-63fe430c |
| SonarQube | https://labs.iximiuz.com/playgrounds/SilverStack-sonarqube-server-7761f36f |
| Nexus | https://labs.iximiuz.com/playgrounds/SilverStack-nexus-server-9a3f87e9 |
| Dev Machine | https://labs.iximiuz.com/playgrounds/SilverStack-dev-machine-e672bcf7 |

### Runbooks

| Topic | URL |
|---|---|
| Stack Journey | https://runbook.ibtisam-iq.com/self-hosted/ci-cd/iximiuz/self-hosted-cicd-stack-journey-from-ec2-to-iximiuz-labs/ |
| Stack Orchestration | https://runbook.ibtisam-iq.com/self-hosted/ci-cd/iximiuz/setup-cicd-stack-orchestration/ |
| Stack Operations | https://runbook.ibtisam-iq.com/self-hosted/ci-cd/iximiuz/cicd-stack-operations/ |
| Dev Machine rootfs | https://runbook.ibtisam-iq.com/containers/iximiuz/rootfs/setup-dev-machine-rootfs-image/ |
| Jenkins rootfs | https://runbook.ibtisam-iq.com/containers/iximiuz/rootfs/setup-jenkins-rootfs-image/ |
| SonarQube rootfs | https://runbook.ibtisam-iq.com/containers/iximiuz/rootfs/setup-sonarqube-rootfs-image/ |
| Nexus rootfs | https://runbook.ibtisam-iq.com/containers/iximiuz/rootfs/setup-nexus-rootfs-image/ |
| Ubuntu base rootfs | https://runbook.ibtisam-iq.com/containers/iximiuz/rootfs/setup-ubuntu-24-04-rootfs-base-image/ |

---

## Resume Bullet Points

### Container Image Engineering

- Designed and published **5 production-grade microVM rootfs images** to GHCR, each built via GitHub Actions with OCI labels, multi-tag strategy (`latest`, version-pinned, date-stamped), and layer cache optimization

- Architected a **layered rootfs inheritance model** — a single `ubuntu-24-04-rootfs` base image propagates systemd, SSH, non-root user, and shell config to all child images, eliminating duplication across Jenkins, SonarQube, Nexus, and Dev Machine images

- Implemented **build-time port substitution** (`__NEXUS_PORT__`, `__SONARQUBE_PORT__`, `__JENKINS_PORT__`) via `sed` in Dockerfiles, making all service configurations fully parameterized with zero manual runtime editing required

- Built a **27-phase DevOps toolchain installer** covering runtimes (Java 21, Python 3, Node.js LTS), Kubernetes CLIs (kubectl, Helm, Kustomize, k9s, kubectx, stern), IaC tools (Terraform, AWS CLI v2, Ansible), and security scanners (Trivy, Gitleaks, cosign, syft)

- Engineered **architecture-aware Nexus installation** — detects CPU arch and constructs the correct Sonatype CDN download URL, with explicit handling for Sonatype's non-standard ARM naming convention (`linux-aarch_64` vs `linux-aarch64`)

- Resolved a **JVM user preferences failure** in a no-home-directory system user (`nexus`) by appending `-Djava.util.prefs.userRoot` to `nexus.vmoptions` and recreating the directory at every boot via `lab-init.sh`

### systemd & Service Orchestration

- Designed a **4-service systemd boot chain** (`lab-init` → `postgresql` → `nginx` → `sonarqube`) with `Before=` / `After=` constraints, ensuring SSH keys, `/run` directories, and database ownership are always correct before any service starts

- Implemented **idempotent PostgreSQL provisioning at runtime** — `lab-init.sh` creates the `sonar` role and `sonarqube` database at every boot without failing on re-runs, because microVM mounts reset state on each playground creation

- Configured **Elasticsearch kernel parameters** (`vm.max_map_count`, `fs.file-max`) at both build time (`/etc/sysctl.conf`) and runtime (`sysctl -w` in `lab-init.sh`), satisfying SonarQube embedded Elasticsearch requirements in a microVM environment

- Applied **limited sudoers profiles** for all service daemon users (`jenkins`, `sonar`, `nexus`) — service control and log inspection only, no full root, minimizing blast radius if a service is compromised

### CI/CD Platform Engineering

- Built and published a **fully composed 4-node CI/CD stack** on iximiuz Labs — Jenkins LTS, SonarQube 26.2 CE, Nexus 3.89.1 CE, and a Dev Machine — all in a single Flexbox playground on a shared private network, with SSH aliases for instant inter-node access

- Designed a **resource-optimized playground manifest** fitting exactly within the Flexbox budget (10 vCPU, 16 GiB RAM, 150 GiB disk) by allocating resources proportionally to service memory profiles

- Configured **Nginx as the canonical entry point** for all service nodes — port 80, `client_max_body_size 1G` for large artifact uploads, proxy headers, and a `/health` endpoint on each node

- Pre-installed `cloudflared` on all service nodes enabling **custom-domain SSL access without firewall rules or public IPs** via Cloudflare Tunnel

### Developer Experience & Tooling

- Built a **DevOps workstation rootfs** with 30+ pre-installed tools, system-wide bash/zsh tab completion for all major CLIs, short aliases (`k`, `d`, `tf`, `g`) wired to full completion functions, and a self-deleting welcome banner on first login

- Designed **post-setup scripts on PATH** (`install-pipeline-tools`, `install-plugins`) for the Jenkins node — intentionally not baked into the image, keeping image size minimal while giving users full control over toolchain versions after boot

### Technical Documentation

- Authored **8 production runbooks** covering rootfs image build procedures, CI/CD stack orchestration, post-provisioning operations, Key Decisions sections explaining non-obvious architectural choices, and Verification sections distinguishing valid (`labctl` microVM) from invalid (`docker run`) test methods

- Documented a **counterintuitive Dockerfile behavior** (`USER $USER` at image end) with a full technical explanation distinguishing OCI image config scope (`docker run`) from microVM boot behavior (platform kernel + systemd), preventing future regressions from well-intentioned "fixes"

- Wrote **5 iximiuz playground landing pages** in professional, scan-optimized Markdown — stack table, boot sequence diagram, access methods, boot time warnings, and credentials — targeted at senior DevOps engineers
