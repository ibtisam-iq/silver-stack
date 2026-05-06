# SilverStack CI/CD Stack

A fully composed **4-node CI/CD platform** - Jenkins, SonarQube,
Nexus, and a Dev Machine, all running in a single Flexbox playground on a shared
private network. Each service is Nginx-proxied and Cloudflare-ready. Zero setup required to boot.

![](__static__/cicd-stack-dev-machine-welcome.png)

## Nodes

| Node | Image | CPU | RAM | Disk | Role |
|---|---|---|---|---|---|
| `dev-machine` | `dev-cicd-rootfs` | 1 vCPU | 1 GiB | 30 GiB | Jump host · entry point |
| `jenkins-server` | `jenkins-rootfs` | 3 vCPU | 4 GiB | 40 GiB | Jenkins LTS · CI/CD orchestrator |
| `sonarqube-server` | `sonarqube-rootfs` | 3 vCPU | 6 GiB | 40 GiB | SonarQube 26.2 CE + PostgreSQL 18 |
| `nexus-server` | `nexus-rootfs` | 3 vCPU | 5 GiB | 40 GiB | Nexus 3.89.1 CE · artifact registry |

**Total:** 10 vCPU · 16 GiB RAM · 150 GiB disk - exactly the Flexbox budget.

## How it works

All four nodes share a local network (`172.16.0.0/24`). SSH directly between nodes
by name from the Dev Machine:

```bash
ssh jenkins-server      then follow steps → jenkins.yourdomain.com
ssh sonarqube-server    then follow steps → sonar.yourdomain.com
ssh nexus-server        then follow steps → nexus.yourdomain.com
```

Each service is accessible via a dedicated **UI tab** in the playground (port 80 via Nginx).
For public access on your own domain, `cloudflared` is pre-installed on each service node.

## Tabs

8 tabs pre-defined: `IDE` · `dev` · `jenkins` · `sonarqube` · `nexus` terminals + `Jenkins UI` · `SonarQube UI` · `Nexus UI`

- The ↗ arrow on each UI tab opens the service in a new browser tab - but only after the tab has been clicked and loaded inside the lab first.

## Boot times (first boot)

| Service | Wait time |
|---|---|
| Jenkins | ~60–90 s |
| SonarQube | ~2–3 min (Elasticsearch) |
| Nexus | ~60–90 s |

## Resources · 10 vCPU / 16 GiB RAM / 150 GiB disk (Flexbox)

## Docs

- Orchestration runbook: https://runbook.ibtisam-iq.com/self-hosted/ci-cd/iximiuz/setup-cicd-stack-orchestration/
- Operations runbook: https://runbook.ibtisam-iq.com/self-hosted/ci-cd/iximiuz/cicd-stack-operations/
