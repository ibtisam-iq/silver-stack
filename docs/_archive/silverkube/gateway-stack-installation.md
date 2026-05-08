# Gateway API + NGINX Gateway Fabric Installer  
A simple one-command installer that sets up:

- Gateway API CRDs  
- NGINX Gateway Fabric CRDs  
- NGINX Gateway Fabric (NodePort deployment)  
- NGINX Ingress Controller (optional)

This installer is part of the **SilverKube** project.

---

## 🚀 Install in One Command

Run the following command on any Kubernetes cluster:

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/SilverKube/main/gateway-stack-installation.sh | bash
````

This will:

1. Install Gateway API CRDs
2. Install NGINX Gateway Fabric CRDs
3. Deploy the NGINX Gateway Fabric controller (NodePort)
4. Install the NGINX Ingress Controller

Everything happens automatically and in the correct order.

---

## 📦 What Gets Installed?

### 1. Gateway API CRDs

From the official upstream repository
(standard installation set).

### 2. NGINX Gateway Fabric CRDs

Required for the NGINX Gateway Fabric controller.

### 3. NGINX Gateway Fabric NodePort Deployment

Deploys the actual gateway controller on your cluster.

### 4. NGINX Ingress Controller

Optional but included for compatibility with existing Ingress workloads.
