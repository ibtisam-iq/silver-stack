# SilverStack SonarQube Server

Production-grade **SonarQube 26.2 CE (LTA)** on Ubuntu 24.04 - systemd-booted,
PostgreSQL-backed, Nginx-proxied, Cloudflare-ready, zero setup required.

![](__static__/sonarqube-server-welcome.png)

## Stack

| Layer | Detail |
|---|---|
| OS | Ubuntu 24.04 · systemd PID 1 |
| Database | PostgreSQL 18 · provisioned at runtime by `lab-init` |
| Runtime | Java 21 (OpenJDK) |
| Service | SonarQube 26.2.0 CE · runs as `sonar` user |
| Proxy | Nginx :80 → SonarQube :9000 |
| Tunnel | `cloudflared` pre-installed |

## Boot sequence

```
systemd
  └── lab-init   (oneshot) - SSH keys, PostgreSQL DB init, sysctl (ES limits)
        └── postgresql       - data store for SonarQube
              └── nginx        - reverse proxy on :80
                    └── sonarqube  - code quality server on :9000
```

- SonarQube takes **2–3 minutes** to fully initialize on first boot (Elasticsearch startup).
- The SonarQube UI tab may show a loading screen - this is normal.

## Accessing SonarQube

**Inside the lab:** click the **SonarQube UI** tab. That's it.

- The ↗ arrow on the tab opens SonarQube in a new browser tab - but only after the **SonarQube UI** tab has loaded inside the lab first.

**Public URL:** `cloudflared` is pre-installed. Install a tunnel token and
point the route to `localhost:80` for SSL access on your own domain.

## First boot credentials

- **Username:** admin
- **Password:** admin

## Resources · 4 vCPU / 10 GiB RAM / 50 GiB disk

## Docs

- GitHub: https://github.com/ibtisam-iq/silver-stack/tree/main/iximiuz/rootfs/sonarqube
- Runbook: https://runbook.ibtisam-iq.com/containers/iximiuz/rootfs/setup-sonarqube-rootfs-image/
- Image: [ghcr.io/ibtisam-iq/sonarqube-rootfs:latest](https://ghcr.io/ibtisam-iq/sonarqube-rootfs:latest)
