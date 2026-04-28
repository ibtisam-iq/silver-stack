#!/bin/bash
# cluster-params.sh

# 📡 Automatically detect Control Plane IP
export CONTROL_PLANE_IP=$(ip route get 8.8.8.8 | awk '{print $7; exit}')

# 🖥️ Get static hostname
export NODE_NAME=$(hostnamectl --static)

# 📦 Pod CIDR (e.g., Flannel)
export POD_CIDR="10.244.0.0/16"

# 📦 Kubernetes Version
export K8S_VERSION="1.34"
