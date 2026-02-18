#!/bin/bash

# ╔══════════════════════════════════════════════════╗
# ║     infra-bootstrap - Kind Cluster Setup Using Calico ║
# ║     (c) 2025 Muhammad Ibtisam Iqbal              ║
# ║     License: MIT                                 ║
# ╚══════════════════════════════════════════════════╝
# 
# 📌 Description:
# This script automates the setup of a kind (Kubernetes in Docker) cluster using Calico. 
# It executes a sequence of scripts to install required tools, and set up the kind cluster.
#   - ✅ System preflight checks
#   - ✅ Docker installation and setup
#   - ✅ kubectl installation
#   - ✅ kind installation
#
# 🚀 Usage:
#   curl -sL https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/kubernetes/k8s-kind-calico.sh | sudo bash
#
# 📜 License: MIT | 🌐 https://github.com/ibtisam-iq/infra-bootstrap

set -e  # Exit immediately if a command fails
set -o pipefail  # Ensure failures in piped commands are detected

# Function to handle script failures
trap 'echo -e "\n\033[1;31m❌ Error occurred at line $LINENO. Exiting...\033[0m\n" && exit 1' ERR

# Define the repository URL
REPO_URL="https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts"

# List of scripts to execute
SCRIPTS=(
    "system-checks/preflight.sh"
    "system-checks/sys-info.sh"
    "components/docker-setup.sh"
    "components/kubernetes-cli.sh"
    "components/kind-setup.sh"
)

# ==================================================
# 🚀 Executing Scripts
# ==================================================
for script in "${SCRIPTS[@]}"; do
    echo -e "\n\033[1;34m🚀 Running $script script...\033[0m"
    bash <(curl -fsSL "$REPO_URL/$script") || { echo -e "\n\033[1;31m❌ Failed to execute $script. Exiting...\033[0m\n"; exit 1; }
    echo -e "\033[1;32m✅ Successfully executed $script.\033[0m\n"
done

# ==================================================
# 🎉 Kind Cluster Setup
# ==================================================
echo -e "\033[1;34m🚀 Setting up kind cluster with Calico...\033[0m"
curl -s https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/kubernetes/manifests/kind-calico-cluster-config.yaml | kind create cluster --config -
echo -e "\033[1;32m✅ Kind cluster created successfully.\033[0m\n"
# ==================================================
# 🎉 Calico Installation
echo -e "\033[1;34m🚀 Installing Calico...\033[0m"
curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml
echo -e "\033[1;32m✅ calico.yaml downloaded successfully.\033[0m\n"
# ==================================================
# Modify the calico.yaml file to use the correct CIDR
echo -e "\033[1;33m🔧 Modifying calico.yaml to use ... \033[0m\n"
sed -i 's/# - name: CALICO_IPV4POOL_CIDR/- name: CALICO_IPV4POOL_CIDR/' calico.yaml
sed -i 's/#   value: "192.168.0.0\/16"/  value: "10.244.0.0\/16"/' calico.yaml
echo -e "\033[1;32m✅ calico.yaml modified successfully.\033[0m\n"
# ==================================================
# Apply the Calico configuration
echo -e "\033[1;34m🚀 Applying Calico configuration...\033[0m"
kubectl apply -f calico.yaml
echo -e "\033[1;32m✅ Calico installed successfully.\033[0m\n"
rm -rf calico.yaml
# ==================================================
# 🎉 Kind Cluster Setup Complete!
# ==================================================
echo -e "\033[1;34m🚀 Setting up kind cluster...\033[0m"
echo -e "\033[1;33m💡 Kind cluster setup may take a few minutes. Please wait...\033[0m\n"
sleep 30
echo -e "\033[1;32m✅ Kind cluster setup completed successfully.\033[0m\n"
# ==================================================
# 🎉 Verify the kind cluster
echo -e "\033[1;34m🚀 Verifying the kind cluster...\033[0m\n"
kubectl get nodes -o wide
echo
kubectl cluster-info
echo -e "\033[1;32m✅ Kind cluster verified successfully.\033[0m\n"
# ==================================================
# 🎉 Install AMOR
echo -e "\033[1;34m🚀 Installing AMOR app for testing the cluster...\033[0m\n"
kubectl apply -f https://raw.githubusercontent.com/ibtisam-iq/SilverKube/main/amor.yaml
# ==================================================
# 🌐 AMOR Access Instructions
# ==================================================
echo -e "\033[1;34m🌐 AMOR App Access URLs\033[0m\n"

PUBLIC_IP=$(curl -s ifconfig.me || echo "Unavailable")

echo -e "💡 AMOR app is exposed via:\n"
echo -e "\033[1;32m▶️  Kind Port Mapping (host:8081 → node:30000):\033[0m"

if [[ "$PUBLIC_IP" != "Unavailable" && "$PUBLIC_IP" != "127.0.0.1" ]]; then
    echo -e "\n📌 It seems, you're on a remote VM or a cloud server, please click on the link below to access the AMOR app:\n"
    echo -e "\033[1;34m🌐 http://${PUBLIC_IP}:8081\033[0m\n"
else
    echo -e "\n📌 Maybe you're running locally, please click on the link below to access the AMOR app:\n"
    echo -e "\033[1;34m🖥️  http://localhost:8081\033[0m\n"
fi

# ==================================================
echo -e "\033[1;34m💡 Final Steps:\033[0m\n"
echo -e "💡 Please run: newgrp docker"
echo -e "💡 Also: kind export kubeconfig --name ibtisam\n"


# ==================================================
# 🎉 Setup Complete! Thank You! 🙌
# ==================================================
echo -e "\n\033[1;33m✨ Thank you for choosing infra-bootstrap - Muhammad Ibtisam 🚀\033[0m\n"
