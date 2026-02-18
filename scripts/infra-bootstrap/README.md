# ⚙️ infra-bootstrap 

[![Documentation Pipeline](https://github.com/ibtisam-iq/infra-bootstrap/actions/workflows/docs-deploy.yml/badge.svg)](https://github.com/ibtisam-iq/infra-bootstrap/actions/workflows/docs-deploy.yml)

<p align="center">
  <img src="https://img.shields.io/badge/Linux-Ubuntu-orange?style=for-the-badge&logo=linux" />
  <img src="https://img.shields.io/badge/Scripting-Bash-black?style=for-the-badge&logo=gnu-bash" />
  <img src="https://img.shields.io/badge/Kubernetes-Automation-blue?style=for-the-badge&logo=kubernetes" />
  <img src="https://img.shields.io/badge/DevOps-Bootstrapping-green?style=for-the-badge" />
</p>

---

## Overview

`infra-bootstrap` is a **Bash-based infrastructure bootstrapping framework** designed to rapidly provision DevOps tooling and Kubernetes environments in disposable lab and cloud instances.

It provides modular, repeatable automation scripts for creating consistent infrastructure without manual setup overhead.

---

## Scope

This project is designed for:

* Learning environments
* Dev/test labs
* Cloud sandboxes
* Disposable VMs

**Not intended for enterprise production systems.**

---

## Prerequisites

This project is designed to run on:

- Ubuntu 20.04 / 22.04 / 24.04
- Ubuntu-based distributions (Linux Mint, Pop!_OS, Debian derivatives)

### System Requirements

- Fresh VM or clean system (recommended)
- Root or sudo privileges
- Stable internet connectivity
- `curl` installed
- `bash` shell available

### Supported Platforms

✅ Ubuntu  
✅ Linux Mint  
✅ Debian-based distros  

❌ CentOS  
❌ RHEL  
❌ SUSE  

This project assumes a clean, disposable system environment.

---

## Engineering Approach

This project intentionally uses **Bash scripting instead of Ansible**.

This was a deliberate engineering decision based on the project goals:

- Faster execution in lab environments
- No dependency bootstrapping required
- Full visibility into system-level changes
- Direct control of package and service state

This project is optimized for:

- Speed of provisioning
- Learning by system-level interaction
- Rapid rebuild of disposable infrastructure

For enterprise-grade infrastructure, tools such as **Ansible, Terraform, and GitOps** are more appropriate.

---

## Design & Execution Model

infra-bootstrap is designed as a modular infrastructure bootstrapping framework, not a sequential automation pipeline.

Each script in this repository is:

- Self-contained and independently executable
- Safe to run in isolation
- Designed to manage its own prerequisites
- Built for repeatable, disposable environments

There is no forced execution order.

Users are expected to run only the scripts they require for their specific use case.

Where applicable, scripts follow idempotent behavior to avoid system breakage and allow safe re-runs.

The project is intentionally Bash-based to maximize speed, visibility, and system-level control rather than acting as a full enterprise orchestration system.

---

## Automated Infrastructure Tooling

A structured collection of scripts for provisioning infrastructure components and DevOps environments.

### 1️⃣ Kubernetes Infrastructure

#### Local / Lightweight Clusters

<details>
<summary>Minikube</summary>

```bash
minikube start
```

</details>

<details>
<summary>Kind</summary>

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/kubernetes/k8s-kind-calico.sh | sudo bash
```

</details>

<details>
<summary>K3s</summary>

```bash
curl -sfL https://get.k3s.io | sh -
```

</details>

---

#### Self-managed Clusters (kubeadm)

<details>
<summary>Control Plane</summary>

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/kubernetes/K8s-Control-Plane-Init.sh | sudo bash
```

</details>

<details>
<summary>Worker Node</summary>

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/kubernetes/K8s-Node-Init.sh | sudo bash
```

</details>

---

#### CNI Layer

<details>
<summary>CNI Setup</summary>

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/kubernetes/k8s-cni-setup.sh | sudo bash
```

</details>

---

#### Gateway & Ingress

<details>
<summary>Gateway + Ingress Stack</summary>

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/kubernetes/gateway-stack-installation.sh | bash
```

</details>

---

### 2️⃣ Pre-built Server Profiles

<details>
<summary>Jumpbox Server</summary>

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/servers/Jumpbox.sh | sudo bash
```

</details>

<details>
<summary>Jenkins Server</summary>

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/servers/Jenkins-Server.sh | sudo bash
```

</details>

<details>
<summary>Jenkins (Standalone)</summary>

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/components/jenkins-setup.sh | sudo bash
```

</details>

---

### 3️⃣ Individual Tool Installers

Standalone installers for direct tool provisioning.

<details>
<summary>🔹 Docker – Container Engine</summary>

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/components/docker-setup.sh | sudo bash
```

</details>

<details>
<summary>🔹 Containerd – Container Runtime</summary>

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/kubernetes/containerd-setup.sh | sudo bash
```

</details>

<details>
<summary>🔹 Ansible – Configuration Management</summary>

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/components/ansible-setup.sh | sudo bash
```

</details>

<details>
<summary>🔹 Terraform – Infrastructure as Code</summary>

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/components/terraform-setup.sh | sudo bash
```

</details>

<details>
<summary>🔹 AWS / EKS Provisioning</summary>

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/components/aws-eks-stack.sh | sudo bash
```

</details>

<details>
<summary>🔹 kubectl + eksctl – Kubernetes Client Tools</summary>

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/components/kubernetes-cli.sh | sudo bash
```

</details>

<details>
<summary>🔹 Helm – Kubernetes Package Manager</summary>

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4 | bash
```

</details>

<details>
<summary>🔹 Trivy – Vulnerability Scanner</summary>

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/components/trivy-setup.sh | sudo bash
```

</details>

<details>
<summary>🔹 SonarQube – Code Quality Scanner</summary>

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/services/sonarqube-cont.sh | sudo bash
```

</details>

<details>
<summary>🔹 Nexus – Artifact Repository</summary>

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/services/nexus-cont.sh | sudo bash
```

</details>

<details>
<summary>🔹 System Health & Updates</summary>

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/system-checks/sys-info-and-update.sh | sudo bash
```

</details>

<details>
<summary>🔹 Installed Package Version Check</summary>

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/system-checks/version-check.sh | sudo bash
```

</details>

---

## Safety Model

This project is designed for controlled, non-production environments.

### Safe Usage
- Disposable VMs
- Short-lived lab systems
- Fast, repeatable provisioning

### Limitations
- Not production hardened
- No rollback or state recovery
- No high-availability design

This project assumes a clean, disposable system state before execution.

---

## Security Notice

This project uses the pattern:

```bash
curl | bash
```

Use only in **trusted** and **disposable** environments.

---

## Contribution Model

Contributions are welcome and encouraged.

### Accepted Contribution Areas
- Expanding tool coverage
- Improving script reliability
- Strengthening documentation clarity
- Optimizing execution performance

### Contribution Workflow
1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Submit a pull request

---

## 📬 Connect with Me

<p align="left">
  <a href="https://linkedin.com/in/ibtisam-iq" target="_blank">
    <img src="https://img.shields.io/badge/-LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white" />
  </a>
</p>

---

## Author

**Muhammad Ibtisam ❤️**
