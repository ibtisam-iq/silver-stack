# 🥈 SilverStack

> The reproducible form of my infrastructure work

SilverStack is the layer where verified understanding becomes runnable, repeatable systems.

It contains only what I can rebuild from scratch with consistent results.

## 🎯 Purpose

When I study a concept or run a setup for the first time, the depth, experiments, and failures are written in my [Knowledge Base](https://nectar.ibtisam-iq.com/).

When that same setup becomes:

- clear  
- trusted  
- repeatable  
- automated  

its final working form is placed here.

This repository is that promoted, reproducible state.

## 🧱 What Lives Here

- Kubernetes manifests  
- Infrastructure as Code  
- CI/CD automation  
- Service deployment patterns  
- Environment provisioning scripts  
- Platform building blocks  

Each item represents something that has been:

1. understood  
2. executed in practice  
3. verified  
4. made rebuildable

## 🚫 What Does Not Belong Here

This is not a learning log and not an experiment space.

You will not find:

- raw notes  
- partial setups  
- trial-and-error  
- copied examples  

Those live in the [Knowledge Base](https://nectar.ibtisam-iq.com/).

## 🔄 How It Fits in My Engineering Workflow

My work follows a consistent flow:

1. Understanding and deep execution → **[Knowledge Base](https://nectar.ibtisam-iq.com/)**
2. Reproducible, trusted configurations → **SilverStack**
3. Distilled practical reasoning → **[Blogs](https://blogs.ibtisam-iq.com/)**
4. Complete running environments → **[Projects](https://projects.ibtisam-iq.com/)**

This repository represents the reproducibility layer in that system.

## ⚙️ Infra Bootstrap

The `infra-bootstrap/` directory contains the automation used to spin up complete environments from a single command.

It is the executable path from:

reusable components → running system

📖 Documentation: https://bootstrap.ibtisam-iq.com

## 💻 Quick Start

### Initialize Kubernetes Control Plane

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/silver-stack/main/infra-bootstrap/scripts/kubernetes/entrypoints/init-controlplane.sh | sudo bash
````

### Join Worker Node

```bash
curl -sL https://raw.githubusercontent.com/ibtisam-iq/silver-stack/main/infra-bootstrap/scripts/kubernetes/entrypoints/init-worker-node.sh | sudo bash
```

## 📚 Related Platforms

* 📖 Knowledge Base → [https://nectar.ibtisam-iq.com](https://nectar.ibtisam-iq.com)
* 🧠 Engineering Blogs → [https://blogs.ibtisam-iq.com](https://blog.ibtisam-iq.com)
* 🏗 Portfolio → [https://ibtisam-iq.com](https://ibtisam-iq.com)

## 🧭 Why This Exists

Running something once is learning.
Rebuilding it reliably is engineering.
