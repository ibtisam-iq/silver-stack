# Rootfs Images

Custom VM root filesystems for [iximiuz Labs](https://labs.iximiuz.com) playgrounds — part of [SilverStack](https://github.com/ibtisam-iq/silver-stack), a personal infrastructure-as-code repository where every environment is codified, versioned, and reproducible.

This is a living collection — new images and stacks are added as new tools are built and validated.

---

## Why Custom Rootfs?

iximiuz Labs runs playgrounds as **full microVMs** — not containers. Each VM boots from a root filesystem mounted at `/`. The default approach is to run init scripts on every playground start, meaning every user waits through the install before they can begin.

A **custom rootfs** solves this: build a Docker image with everything pre-installed, push it to a public OCI registry, and reference it as the VM drive source using the `oci://` prefix:

```yaml
drives:
  - source: oci://ghcr.io/ibtisam-iq/jenkins-rootfs:latest
    mount: /
    size: 30GiB
```

The VM boots with everything already in place. **Zero install time. Instant prompt.**

---

## Accessing Services on a Custom Domain

iximiuz Labs provides `labctl expose` which generates a URL for any port inside the VM. This works for quick ad-hoc access, but the URL is iximiuz-generated, not your own domain.

To make any service reachable on a **persistent custom domain with SSL** (e.g., `jenkins.ibtisam-iq.com`) without any manual steps on every boot, two components are baked into the rootfs image:

- **Nginx** — reverse proxy that forwards port 80 to the service's internal port
- **cloudflared** — runs on VM boot and creates an outbound Cloudflare Tunnel mapped to a custom domain with automatic SSL

This approach is used only when a service needs to be reachable on a custom domain — images that do not serve over a public URL do not include it.

---

## Images

All images build on top of `ubuntu-24-04-rootfs` (Ubuntu 24.04 + systemd, SSH, bash, vim, git, fzf).

| Image | GHCR | Type | Nginx + Tunnel |
|---|---|---|---|
| [`ubuntu/`](ubuntu/) | `ghcr.io/ibtisam-iq/ubuntu-24-04-rootfs:latest` | Base | — |
| [`dev/machine/`](dev/machine/) | `ghcr.io/ibtisam-iq/dev-machine-rootfs:latest` | Dev environment | — |
| [`jenkins/`](jenkins/) | `ghcr.io/ibtisam-iq/jenkins-rootfs:latest` | `jenkins.ibtisam-iq.com` | ✓ |
| [`nexus/`](nexus/) | `ghcr.io/ibtisam-iq/nexus-rootfs:latest` | `nexus.ibtisam-iq.com` | ✓ |
| [`sonarqube/`](sonarqube/) | `ghcr.io/ibtisam-iq/sonarqube-rootfs:latest` | `sonar.ibtisam-iq.com` | ✓ |

---

## Usage

All playground manifests live in [`iximiuz/manifests/`](../manifests/).

**Standalone — single service:**

```bash
labctl playground create --base flexbox dev-machine      -f iximiuz/manifests/dev-machine.yml
labctl playground create --base flexbox jenkins-server   -f iximiuz/manifests/jenkins-server.yml
labctl playground create --base flexbox nexus-server     -f iximiuz/manifests/nexus-server.yml
labctl playground create --base flexbox sonarqube-server -f iximiuz/manifests/sonarqube-server.yml
```

**Complete Stack — group of services:**

```bash
# CI/CD Stack: Jenkins, Nexus, SonarQube — SSL Integrated Custom Domain
labctl playground create --base flexbox cicd-stack -f iximiuz/manifests/cicd-stack.yml
```

## Configuration

- All images are built with Docker build arguments — usernames, ports, domains, and other parameters are fully customizable at build time.
- Each image documents its available arguments and instructions for building your own variant in its individual `README.md`.
