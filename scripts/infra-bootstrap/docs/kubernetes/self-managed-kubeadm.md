# Self-Managed Kubernetes Cluster Using kubeadm

## Overview

This guide explains how to build a **self-managed Kubernetes cluster** using `kubeadm` combined with the infra-bootstrap automation scripts.

This method follows the real sequence used by cluster operators:

- Promote a machine to become a **control plane**
- Optionally add **more control planes**
- Prepare worker nodes
- Join all nodes to the cluster
- Install a **CNI plugin**
- Validate the cluster

--8<-- "includes/common-header.md"
--8<-- "includes/system-requirements.md"

---

# 1. Create the First Control Plane

Run the following on the machine you want to become the **primary control plane**:

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/kubernetes/K8s-Control-Plane-Init.sh | sudo bash
```

This script:

- Prepares the node
- Cleans previous kubeadm data
- Starts container runtime + kubelet
- Runs `kubeadm init`
- Configures kubeconfig
- Produces join commands for workers and additional control planes

After completion, your **cluster exists** — but with a single control-plane.

---

# 2. (Optional) Create Additional Control Planes

If you want **multi-control-plane** (HA) setup:

Run **the same script** on your additional control plane nodes:

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/kubernetes/K8s-Control-Plane-Init.sh | sudo bash
```

During initialization of the first node, kubeadm prints the **control-plane join command**, e.g.:

```
kubeadm join <API-SERVER-IP>:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --control-plane
```

Copy that and run it on your additional control-plane nodes.

If the token expired:

```bash
kubeadm token create --print-join-command
```

---

# 3. Prepare Worker Nodes

On every node you want to convert into a **worker**, run:

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/kubernetes/K8s-Node-Init.sh | sudo bash
```

This script:

- Installs containerd
- Installs kubelet / kubeadm / kubectl
- Applies kernel modules + sysctl
- Enables required services

Each machine becomes Kubernetes-ready.

---

# 4. Join Worker Nodes

Joining nodes uses the command printed during the first control-plane init:

```
kubeadm join <API-SERVER-IP>:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

Run this **on each worker node**.

If the token expires:

```bash
kubeadm token create --print-join-command
```

---

# 5. Install a CNI Plugin (Required for Networking)

Kubernetes will not schedule pods until a CNI is installed.

To deploy a CNI via infra-bootstrap:

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/kubernetes/k8s-cni-setup.sh | bash
```

This script:

- Prompts you to choose Calico, Flannel, or Weave
- Applies the correct manifest
- Verifies networking readiness

**Important:**
Install the CNI **only once**, on the first control-plane node.

---

# 6. Verify the Cluster

### Check nodes:

```bash
kubectl get nodes
```

### Check system pods:

```bash
kubectl get pods -A
```

### Check control-plane health:

```bash
kubectl get componentstatuses
```

### Check API server readiness:

```bash
kubectl get --raw='/readyz?verbose'
```

If everything is Running/Ready — your Kubernetes cluster is healthy.

---

# Reset / Rebuild (if needed)

```bash
sudo kubeadm reset -f
sudo systemctl restart containerd
sudo rm -rf ~/.kube
```

---

# Official Reference

**Kubeadm Upstream Documentation:**
[https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
