scripts/kubernetes/
│
├── entrypoints/
│   ├── create-kind-cluster.sh
│   ├── init-control-plane.sh
│   ├── init-worker-node.sh
│
├── cluster/
│   ├── cluster-params.sh          # NEVER run directly
│   ├── silver-stack-control-plane.sh            # internal
│   ├── kube-config-setup.sh       # internal
│   ├── k8s-start-services.sh  = ensure-k8s-services.sh        # internal
│   ├── readiness-check.sh
│
├── runtime/
│   ├── install-containerd.sh
│   ├── install-cni-binaries.sh
│
├── networking/
│   ├── cni-selector.sh
│   ├── install-calico.sh
│   ├── install-flannel.sh
│   ├── install-weave.sh
│
├── node/
│   ├── disable-swap.sh
│   ├── load-kernal-modules.sh
│   ├── apply-sysctl.sh
│  
├── packages/
│   ├── install-k8s-packages.sh
│   
├── addons/
│   ├── gateway-stack.sh
│
├── maintenance/
│   ├── check-readiness.sh
│   ├── k8s-cleanup.sh = detect-existing-cluster.sh + cleanup-cluster.sh
    cleanup-cni.sh
│
└── manifests/

cluster-params.sh... install-containerd.sh + cni tarball
kubeadm-init.sh = silver-stack-control-plane.sh
K8s-Node-Init.sh = node/prepare-node.sh + runtime/install-containerd.sh + packages/install-k8s-packages.sh
K8s-Control-Plane-Init.sh = K8s-Node-Init.sh + cluster/k8s-cleanup.sh + cluster/k8s-start-services.sh + cluster/kubeadm-init.sh + cluster/kube-config-setup.sh
k8s-cni-setup.sh = networking/cni-selector.sh + maintenance/cni-cleanup.sh + networking/install-<cni>.sh


❌ k8s-cleanup.sh is currently both a detector and a destroyer: 

### 🔴 Problem 4: Mixing concerns

This script currently mixes:

| Concern         | Should it be here? |
| --------------- | ------------------ |
| Detection       | Yes                |
| User prompt     | Maybe              |
| Cleanup         | Yes                |
| kubeadm reset   | Optional           |
| Process killing | Separate           |
| Port management | Separate           |

---

## B. Split responsibilities (this is key)

### 1️⃣ Detection script (SAFE)

📁 `scripts/kubernetes/maintenance/`

`detect-existing-cluster.sh`

Responsibilities:

* Check files
* Check ports
* Check services
* Print summary
* Exit **without modifying anything**

Used by:

* silver-stack-control-plane
* join-worker
* menu previews

---

### 2️⃣ Reset script (interactive)

`reset-k8s-node.sh`

Responsibilities:

* Ask confirmation
* Run `kubeadm reset -f`
* Clean known kubeadm artifacts
* Do NOT kill arbitrary processes
* Do NOT free ports blindly

---

### 3️⃣ Force cleanup (expert-only)

`force-clean-k8s-node.sh`

Responsibilities:

* Brutal cleanup
* Kill processes
* Remove etcd
* Remove PKI
* Remove CNI
* Free ports

This is **never auto-run**.
This is for “I know what I’m doing”.

---

## 6. What happens to your existing script?

Nothing is wasted.

### Your current `k8s-cleanup.sh` becomes:

➡️ **`force-clean-k8s-node.sh`**

With:

* louder warnings
* explicit naming
* no auto-invocation

---

## 7. How silver-stack flow should work (very important)

### Control plane silver-stack flow (clean)

1. Detect existing cluster
2. If found:

   * warn
   * explain options
   * STOP
3. User explicitly runs reset script
4. User re-runs silver-stack

No automatic destruction.

---

ibtisam@iq:~/git/silver-stack/scripts/kubernetes$ tree runtime/
runtime/
├── config-containerd-binary.sh
├── config-containerd-package.sh
├── install-containerd.sh           # Entry point script
├── install-cni-binaries.sh
├── install-containerd-binary.sh
├── install-containerd-package.sh
└── install-runc.sh

1 directory, 8 files
ibtisam@iq:~/git/silver-stack/scripts/kubernetes$

cni-binaries.sh, install-crictl.sh, install-containerd.sh