# Kubernetes CNI Installation

**Script:** `k8s-cni-setup.sh`

--8<-- "includes/common-header.md"
--8<-- "includes/system-requirements.md"

---

## 🧭 Overview

A Kubernetes cluster created with kubeadm will **not schedule pods** until a **Container Network Interface (CNI)** is installed.

The infra-bootstrap CNI installer simplifies this process by:

- Allowing you to choose Calico, Flannel, or Weave
- Applying the correct upstream manifest
- Verifying networking readiness
- Handling common networking prerequisites

CNI must be installed **only on the first control-plane node**.

---

# 🧩 What a CNI Does

A CNI plugin enables:

- Pod-to-pod networking
- Pod IP allocation
- Routing inside the cluster
- Network policies (for plugins that support it, e.g., Calico)
- Cross-node communication

Without a CNI plugin:

- Pods remain in **Pending** state
- kube-dns/CoreDNS cannot start
- Networking between nodes does not work

---

# 🚀 Install CNI (Interactive Script)

Run the infra-bootstrap CNI script:

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/kubernetes/k8s-cni-setup.sh | bash
```

The script will:

1. Prompt you to choose a CNI
1. Deploy the selected plugin
1. Validate pod networking
1. Check that CoreDNS becomes Ready
1. Confirm the cluster is operational

---

# 📦 Supported CNI Plugins

Below are the plugins supported by infra-bootstrap with descriptions and use cases.

## 1. **Calico** (Recommended)

### Why choose Calico?

- Network policies (advanced security)
- Stable and widely used in production
- High performance
- IPv4 and IPv6 support
- Works on cloud, bare-metal, and labs

### Manifest used:

```
https://docs.projectcalico.org/manifests/calico.yaml
```

### Recommended for:

- Learning production networking
- Clusters needing NetworkPolicies
- Multi-node setups

---

## ### 2. **Flannel** (Simple, lightweight)

### Why choose Flannel?

- Very simple
- Lightweight
- Perfect for learning
- No advanced networking complexity

### Manifest used:

```
https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

### Recommended for:

- Local clusters
- Lightweight nodes
- Simple labs

---

## ### 3. **Weave Net** (Automatic, simple)

### Why choose Weave?

- Automatic routing
- Does not require special config
- Handles dynamic topology changes
- Easy installation

### Manifest used:

```
https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')
```

### Recommended for:

- Quick setups
- Basic clusters
- Cloud VMs

---

# 🛠 How the k8s-cni-setup.sh Script Works

Your script:

1. Detects Kubernetes version

1. Prints supported CNI options

1. Asks user for selection

1. Downloads and applies the correct manifest

1. Waits for:

    - kube-system pods
    - CNI pods
    - CoreDNS readiness

1. Prints post-installation checks

This ensures the cluster becomes functional immediately after CNI installation.

---

# 🧪 Verify CNI Installation

### Check pods:

```bash
kubectl get pods -n kube-system
```

### Check node status:

```bash
kubectl get nodes
```

### Check CoreDNS:

```bash
kubectl get pods -n kube-system | grep coredns
```

You should see **Running / Ready**.

### Test pod-to-pod networking:

```bash
kubectl run test --image=busybox -- sleep 3600
kubectl exec -it test -- ping <another-pod-ip>
```

---

# 🐛 Troubleshooting

### Pods stuck in Pending

Check CNI pods:

```bash
kubectl get pods -n kube-system | grep -E 'calico|flannel|weave'
```

### CoreDNS not starting

Likely caused by missing CNI. Reinstall the plugin.

### CNI pods CrashLoop

Check logs:

```bash
kubectl logs -n kube-system <pod-name>
```

### Nodes show NotReady

Check kubelet status:

```bash
systemctl status kubelet
```

---

# 🧹 Reset CNI (Advanced)

To reset an incorrect CNI:

```bash
kubectl delete -f <CNI manifest>
kubectl delete pods -n kube-system --all
```

Then reinstall using the infra-bootstrap script.

# 📘 Official Documentation

- Calico: [https://projectcalico.org](https://projectcalico.org)
- Flannel: [https://github.com/flannel-io/flannel](https://github.com/flannel-io/flannel)
- Weave: [https://www.weave.works/docs/net/latest/kubernetes/kube-addon/](https://www.weave.works/docs/net/latest/kubernetes/kube-addon/)
- Kubernetes Networking: [https://kubernetes.io/docs/concepts/cluster-administration/networking/](https://kubernetes.io/docs/concepts/cluster-administration/networking/)
