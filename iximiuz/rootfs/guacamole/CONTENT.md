# SilverStack Guacamole Server

Production-grade **Apache Guacamole 1.6.0** on Ubuntu 24.04 — systemd-booted, MariaDB-backed, Nginx-proxied, XRDP-connected, Cloudflare-ready, zero setup required.

![](/__static__/guacamole-server-welcome.png)

## Stack

| Layer | Detail |
|---|---|
| OS | Ubuntu 24.04 · systemd PID 1 |
| Database | MariaDB · provisioned at runtime by `lab-init` |
| Guacamole daemon | `guacd` 1.6.0 · compiled from source |
| Web app | Apache Guacamole 1.6.0 WAR · Tomcat 10 |
| Desktop | XFCE4 · XRDP :3389 |
| Proxy | Nginx :80 → Tomcat :8080 |
| Tunnel | `cloudflared` pre-installed |

## Boot sequence

```text
systemd
└── lab-init (oneshot)
    - SSH keys, MariaDB DB init, password injection
    └── mariadb        - data store for Guacamole
    └── guacd          - Guacamole proxy daemon on :4822
    └── xrdp           - RDP server on :3389
    └── tomcat10       - Guacamole web app on :8080
    └── nginx          - reverse proxy on :80
```

- Tomcat takes **30–60 seconds** to unpack and deploy the WAR on first boot.
- The Guacamole UI tab may show a loading screen — this is normal.

## Accessing Guacamole

**Inside the lab:** click the **Guacamole UI** tab. That's it.

- The ↗ arrow on the tab opens Guacamole in a new browser tab — but only after the **Guacamole UI** tab has loaded inside the lab first.

**Public URL:** `cloudflared` is pre-installed. Install a tunnel token and point the route to `localhost:80` for SSL access on your own domain.

## First boot credentials

- **Guacamole Username:** guacadmin
- **Guacamole Password:** guacadmin
- **RDP User:** devuser
- **RDP Password:** generated at boot (printed in `lab-init` journal)

## Resources

· 4 vCPU / 10 GiB RAM / 50 GiB disk

## Docs

- GitHub: https://github.com/ibtisam-iq/silver-stack/tree/main/iximiuz/rootfs/guacamole
- Runbook: https://runbook.ibtisam-iq.com/containers/iximiuz/rootfs/setup-guacamole-rootfs-image/
- Image: [ghcr.io/ibtisam-iq/guacamole-rootfs:latest](https://ghcr.io/ibtisam-iq/guacamole-rootfs:latest)
