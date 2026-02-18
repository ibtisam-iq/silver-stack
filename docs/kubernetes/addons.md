# Kubernetes Add-Ons

**Networking, Ingress, Gateways, and Traffic Management**

--8<-- "includes/common-header.md"
--8<-- "includes/system-requirements.md"

---

## 🧭 Overview

Kubernetes Add-Ons extend the capabilities of a cluster.
They are optional components that enable:

- Traffic routing
- Load balancing
- Ingress management
- Gateway API support
- Service mesh integrations
- L7 traffic control
- North-south and east-west networking

This page covers **the add-ons installed by infra-bootstrap**, including:

1. **Gateway API CRDs**
1. **NGINX Gateway Fabric**
1. **NGINX Ingress Controller (optional)**
1. **Traefik (NodePort)**

These tools provide a complete ingress and API gateway layer for small clusters, labs, and learning environments.

---

# 🧩 What Are Kubernetes Add-Ons?

Add-Ons are not required for the control-plane or worker nodes to function, but they are essential when you want:

- Exposing applications to the outside world
- Managing HTTP/HTTPS routing
- Applying networking rules
- Running production-like routing in a lab environment
- Testing real application traffic

The add-ons below provide:

| Add-On                   | Purpose                                   |
| ------------------------ | ----------------------------------------- |
| **Gateway API CRDs**     | Modern Kubernetes L4/L7 routing interface |
| **NGINX Gateway Fabric** | Gateway API implementation by NGINX       |
| **Ingress-NGINX**        | Traditional Kubernetes Ingress Controller |
| **Traefik**              | Ingress + Gateway + L7 routing (NodePort) |

---

# 🚀 Automatic Installation Script

To install all add-ons:

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/kubernetes/gateway-stack-installation.sh | bash
```

(The script name is assumed; rename accordingly if needed.)

The script installs:

- Gateway API CRDs
- NGINX Gateway Fabric
- NGINX Ingress Controller
- Traefik Ingress Controller (NodePort)
- Helm (required for Traefik)

---

# 🧱 Add-Ons Installed by infra-bootstrap

Below is exactly what your script does and why it matters.

---

## 🧊 1. Gateway API CRDs

Gateway API is the **next-generation** networking API for Kubernetes (successor to Ingress).

Your script installs the official CRDs:

```bash
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v1.5.1" \
| kubectl apply -f -
```

### Why this matters

- Enables `GatewayClass`, `Gateway`, `HTTPRoute`, `TCPRoute`, etc.
- Required for NGINX Gateway Fabric
- Modern L4/L7 routing model
- More flexible than old Ingress resources

---

## 🌐 2. NGINX Gateway Fabric (NodePort)

CRDs first:

```bash
kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v1.6.1/deploy/crds.yaml
```

Main deployment:

```bash
kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v1.6.1/deploy/nodeport/deploy.yaml
```

### What it provides

- Gateway API implementation by NGINX
- NodePort-based external access
- High-performance routing engine
- Easy HTTP/HTTPS traffic management

---

## 🌐 3. NGINX Ingress Controller (Optional)

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.13.0/deploy/static/provider/cloud/deploy.yaml
```

### What it provides

- Traditional Kubernetes Ingress
- Stable and widely used in production
- Works with simple `Ingress` YAML manifests
- Good for basic routing workloads

This is optional and not required if you plan to use Gateway API exclusively.

---

## ⚡ 4. Traefik (NodePort 32080/32443)

Before Traefik can be installed, your script:

- Installs Helm v4
- Adds the Traefik chart repo
- Updates Helm repository cache

Then installs Traefik:

```bash
helm upgrade --install traefik traefik/traefik \
  --namespace traefik \
  --set ports.web.nodePort=32080 \
  --set ports.websecure.nodePort=32443 \
  --set service.type=NodePort \
  --create-namespace \
  --skip-crds
```

### What Traefik provides

- Ingress Controller
- Gateway API support
- HTTPS termination
- Automatic certificate management (if enabled)
- Dashboard support
- NodePort access on:

| Port      | Purpose |
| --------- | ------- |
| **32080** | HTTP    |
| **32443** | HTTPS   |

---

# 🧪 Verification Steps

After installation:

### Check all namespaces:

```bash
kubectl get ns
```

### Check add-on pods:

```bash
kubectl get pods -A | grep -E "gateway|nginx|traefik"
```

### Check Gateway API CRDs:

```bash
kubectl get crd | grep gateway
```

### Check Traefik dashboard (if enabled):

```
http://<node-ip>:32080
```

### Check NGINX Fabric resources:

```bash
kubectl get gatewayclass
kubectl get gateways
kubectl get httproutes
```

---

# 🐛 Troubleshooting

### Add-on pods stuck in CrashLoop

```bash
kubectl logs -n <namespace> <pod-name>
```

### Gateway API not working

Check CRDs:

```bash
kubectl get crd | grep gateway
```

### NodePort not reachable

Check firewall or cloud provider security groups.

### Traefik not installing

Ensure Helm is installed correctly:

```bash
helm version
```

---

# 📘 Official Documentation

- Gateway API: [https://gateway-api.sigs.k8s.io](https://gateway-api.sigs.k8s.io)
- NGINX Gateway Fabric: [https://github.com/nginx/nginx-gateway-fabric](https://github.com/nginx/nginx-gateway-fabric)
- Ingress-NGINX: [https://kubernetes.github.io/ingress-nginx](https://kubernetes.github.io/ingress-nginx)
- Traefik: [https://doc.traefik.io/traefik](https://doc.traefik.io/traefik)
