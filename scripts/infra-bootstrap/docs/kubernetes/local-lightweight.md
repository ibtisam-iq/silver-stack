# Local & Lightweight Kubernetes Clusters

**Minikube · Kind · K3s**

--8<-- "includes/common-header.md"
--8<-- "includes/system-requirements.md"

---

## 🧭 Overview

This section covers **all methods for running Kubernetes locally** for:

- Learning
- Labs
- Testing
- CI environments
- Disposable cluster experimentation

These cluster types are **not for production**.
They are designed to be small, fast, and easy to rebuild.

This guide includes the three most widely used local cluster tools:

1. **Minikube**
1. **Kind (Kubernetes-in-Docker)**
1. **K3s (Lightweight Kubernetes by Rancher)**

Each tool comes with a simple one-line command to help you spin up a cluster quickly.

---

# 🧊 1. Minikube

Minikube is the most common tool for local Kubernetes.

### Install Minikube

(If not already installed)

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
```

### Start a Cluster

```bash
minikube start --driver=docker
```

### Check Status

```bash
minikube status
```

Minikube automatically deploys a CNI, kubelet, scheduler, and controller manager internally.

---

# 🐳 2. Kind (Kubernetes in Docker)

Kind runs Kubernetes **inside Docker containers**.
It is clean, fast, ephemeral, and perfect for labs.

To create a Kind cluster, infra-bootstrap provides two configurations:

---

## **A) Kind with Calico CNI**

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/kubernetes/k8s-kind-calico.sh | sudo bash
```

This configuration:

- Creates 1 control-plane + 1 worker
- Applies Calico as networking backend
- Configures API server port mapping
- Prepares kubeconfig automatically

---

## **B) Kind with Default CNI (Flannel)**

```bash
curl -s https://raw.githubusercontent.com/ibtisam-iq/SilverKube/main/scripts/kubernetes/manifests/kind-config-file.yaml \
| kind create cluster --config -
```

This configuration:

- Uses default Kind networking (based on flannel-style routing)
- Creates multi-node topology
- No additional network plugin setup needed

---

# ⚡ 3. K3s (Lightweight Kubernetes Engine)

K3s is the smallest, fastest CNCF-certified Kubernetes distribution.
Perfect for:

- VMs
- Raspberry Pi
- Small servers
- Learning Kubernetes without heavy components

Run:

```bash
curl -sfL https://get.k3s.io | sh -
```

### Verify:

```bash
sudo k3s kubectl get nodes
```

K3s includes:

- Containerd
- Flannel networking
- Lightweight control-plane components
- Automatic configuration of kubeconfig

---

# 🧪 Cluster Verification (All Methods)

Regardless of how you created the cluster, verify using:

### Check nodes:

```bash
kubectl get nodes
```

### Check pods:

```bash
kubectl get pods -A
```

### Check cluster info:

```bash
kubectl cluster-info
```

### Check kubeconfig:

```bash
kubectl config view
```

---

# 🧹 Optional: Delete the Cluster

### Minikube

```bash
minikube delete
```

### Kind

```bash
kind delete cluster --name <cluster-name>
```

### K3s

```bash
sudo /usr/local/bin/k3s-uninstall.sh
```

# 📘 Official References

- Minikube: [https://minikube.sigs.k8s.io](https://minikube.sigs.k8s.io)
- Kind: [https://kind.sigs.k8s.io](https://kind.sigs.k8s.io)
- K3s: [https://k3s.io](https://k3s.io)