# SilverStack Jenkins Server

Production-grade **Jenkins LTS** on Ubuntu 24.04 - systemd-booted,
Nginx-proxied, Cloudflare-ready, zero setup required.

![](__static__/jenkins-server-welcome.png)

- Pipeline tools and plugins are **not** baked in - kept intentionally lean.
- Two post-setup scripts are on `PATH` and ready to run after boot.

## Stack

| Layer | Detail |
|---|---|
| OS | Ubuntu 24.04 · systemd PID 1 |
| Runtime | Java 21 (OpenJDK) |
| Service | Jenkins LTS · runs as `jenkins` user |
| Proxy | Nginx :80 → Jenkins :8080 |
| Tunnel | `cloudflared` pre-installed |

## Boot sequence

```
systemd
  └── lab-init   (oneshot) - SSH keys, /run dirs
        └── nginx            - reverse proxy on :80
              └── jenkins    - CI server on :8080
```

- Jenkins takes **60–90 seconds** to fully initialize on first boot.
- The Jenkins UI tab may show a loading screen during this period - this is normal.

## Post-setup scripts (run after boot, not during build)

```bash
install-pipeline-tools   # Maven, Docker, kubectl, Helm, and more
install-plugins          # Recommended Jenkins plugin set
```

## Accessing Jenkins

**Inside the lab:** click the **Jenkins UI** tab. That's it.

- The ↗ arrow on the tab opens Jenkins in a new browser tab - but only after the **Jenkins UI** tab has loaded inside the lab first.

**Public URL:** `cloudflared` is pre-installed. Install a tunnel token and
point the route to `localhost:80` for SSL access on your own domain.

## First boot credentials

```bash
cat /var/lib/jenkins/secrets/initialAdminPassword
```

## Resources · 4 vCPU / 10 GiB RAM / 50 GiB disk

## Docs

- GitHub: https://github.com/ibtisam-iq/silver-stack/tree/main/iximiuz/rootfs/jenkins
- Runbook: https://runbook.ibtisam-iq.com/containers/iximiuz/rootfs/setup-jenkins-rootfs-image/
- Image: [ghcr.io/ibtisam-iq/jenkins-rootfs:latest](https://ghcr.io/ibtisam-iq/jenkins-rootfs:latest)
