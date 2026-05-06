# SilverStack Nexus Server

A production-grade **Nexus Repository Manager 3 Community Edition** on
Ubuntu 24.04 - systemd-booted, Nginx-proxied, Cloudflare-ready, zero setup required.

![](__static__/nexus-server-welcome.png)

## Stack

| Layer | Detail |
|---|---|
| OS | Ubuntu 24.04 - systemd as PID 1 |
| Runtime | Java 21 (OpenJDK) |
| Service | Nexus 3.89.1-02 CE - runs as the `nexus` system user |
| Reverse proxy | Nginx on port 80 → proxies to Nexus on 8081 |
| Tunnel client | `cloudflared` pre-installed for public domain access via Cloudflare Tunnel |

## Boot sequence

```
systemd
  └── lab-init   (oneshot) - SSH keys, /run dirs, Nexus data ownership
        └── nginx            - reverse proxy on :80
              └── nexus      - artifact server on :8081
```

## Accessing Nexus

**Inside the lab:** click the **Nexus UI** tab. That's it.

- The ↗ arrow on the tab opens Nexus in a new browser tab - but only after the **Nexus UI** tab has loaded inside the lab first.

**Public URL:** `cloudflared` is pre-installed. Install a tunnel token and
point the route to `localhost:80` for SSL access on your own domain.

## First boot credentials

```bash
cat /opt/sonatype-work/nexus3/admin.password
```

## Resources

- **4 vCPU / 10 GiB RAM / 50 GiB disk**
- Nexus takes 60–90 seconds to fully initialize on first boot

## Docs

- GitHub: https://github.com/ibtisam-iq/silver-stack/tree/main/iximiuz/rootfs/nexus
- Runbook: https://runbook.ibtisam-iq.com/containers/iximiuz/rootfs/setup-nexus-rootfs-image/
- Image: [ghcr.io/ibtisam-iq/nexus-rootfs:latest](https://ghcr.io/ibtisam-iq/nexus-rootfs:latest)
