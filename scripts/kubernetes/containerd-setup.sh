#!/bin/bash

# ==================================================
# silver-stack - Containerd Setup
# --------------------------------------------------
# This script installs Containerd on Ubuntu or Linux Mint.
# Author: Muhammad Ibtisam Iqbal
# License: MIT
# Version: 1.0
# Usage: sudo bash containerd-setup.sh
# ==================================================

set -e  # Exit immediately if a command fails
set -o pipefail  # Ensure failures in piped commands are detected

# Handle script failures
trap 'echo -e "\n\033[1;31m❌ Error occurred at line $LINENO. Exiting...\033[0m\n" && exit 1' ERR

REPO_URL="https://raw.githubusercontent.com/ibtisam-iq/silver-stack/main/scripts/system-checks"

# ==================================================
# 🛠️ Preflight Check
# ==================================================
echo -e "\n\033[1;34m🚀 Running preflight.sh script to ensure system meets requirements for Containerd...\033[0m"
bash <(curl -sL "$REPO_URL/preflight.sh") || { echo -e "\n\033[1;31m❌ Failed to execute preflight.sh. Exiting...\033[0m"; exit 1; }
echo -e "\n\033[1;32m✅ System meets the requirements for Containerd installation.\033[0m"

# Update system and install dependencies
echo -e "\n\033[1;34m🚀 Updating package list and installing dependencies...\033[0m"
sudo apt update -qq && sudo apt install -yq ca-certificates curl jq gpg > /dev/null

# Add Docker repository for containerd installation
echo -e "\033[1;34m✅ Adding Docker repository for containerd installation...\033[0m"
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update -qq

# Install containerd
echo -e "\n\033[1;34m✅ Installing container runtime (containerd)...\033[0m"
sudo apt-get install -yq containerd.io > /dev/null 2>&1

# Configure containerd
echo -e "\n\033[1;34m✅ Verifying containerd service file path...\033[0m"
sudo systemctl show -p FragmentPath containerd

echo -e "\n\033[1;34m✅ Configuring containerd...\033[0m"
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null || { echo -e "\n\033[1;31m❌ Failed to generate /etc/containerd/config.toml. Exiting...\033[0m"; exit 1; }

if grep -q 'SystemdCgroup = false' /etc/containerd/config.toml; then
    sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    echo -e "\n\033[1;32m✅ SystemdCgroup set to true.\033[0m"
else
    echo -e "\n\033[1;32m✅ SystemdCgroup is already set to true.\033[0m"
fi

# Restart containerd
echo -e "\n\033[1;34m🔄 Restarting containerd...\033[0m"
sudo systemctl restart containerd
sudo systemctl enable containerd --now

# Validate containerd installation
echo -e "\n\033[1;34m🔍 Checking SystemdCgroup setting in config...\033[0m"
sleep 10
grep 'SystemdCgroup' /etc/containerd/config.toml

# Adding CNI plugins
echo -e "\n\033[1;34m✅ Ensuring CNI plugins directory exists...\033[0m"
sudo mkdir -p /opt/cni/bin

echo -e "\n\033[1;34m✅ Fetching latest CNI plugin version...\033[0m"
CNI_VERSION=$(curl -s https://api.github.com/repos/containernetworking/plugins/releases/latest | jq -r '.tag_name')
CNI_TARBALL="cni-plugins-linux-amd64-${CNI_VERSION}.tgz"

if [[ ! -f "$CNI_TARBALL" ]]; then
    echo -e "\n\033[1;34m✅ Downloading CNI plugins...\033[0m"
    wget -q "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/${CNI_TARBALL}"
fi

if [[ -f "$CNI_TARBALL" ]]; then
    echo -e "\n\033[1;34m✅ Extracting CNI plugins...\033[0m"
    sudo tar -C /opt/cni/bin -xzvf "$CNI_TARBALL" > /dev/null
    rm -f "$CNI_TARBALL"
else
    echo -e "\n\033[1;31m❌ Failed to download CNI plugins. Exiting...\033[0m"
    exit 1
fi

# Validate CNI plugin installation
echo -e "\n\033[1;34m✅ Validating CNI plugin installation...\033[0m"
sudo ls /opt/cni/bin/ || { echo -e "\n\033[1;31m❌ CNI plugins not found. Exiting...\033[0m"; exit 1; }

sudo systemctl enable containerd --now
sudo systemctl restart containerd

if systemctl is-active --quiet containerd; then
    echo -e "\n\033[1;32m✅ Containerd is running successfully.\033[0m"
else
    echo -e "\n\033[1;31m❌ Containerd failed to start. Check logs with: sudo journalctl -u containerd --no-pager\033[0m"
    exit 1
fi

# Pull Alpine image to test containerd
echo -e "\n\033[1;34m✅ Pulling Alpine image to test containerd...\033[0m"
sudo ctr images pull docker.io/library/alpine:latest

# Validate containerd and CNI plugin versions
echo -e "\n\033[1;32m✅ Containerd version: $(containerd --version | awk '{print $3}')\033[0m"
echo -e "\033[1;32m✅ Runc version: $(runc --version | awk '{print $3}')\033[0m"

echo -e "\n\033[1;33m🎉 Containerd and CNI plugins setup completed successfully!\033[0m\n"

# ==================================================
# 🎉 Setup Complete! Thank You! 🙌
# ==================================================
echo -e "\n\033[1;33m✨  Thank you for choosing silver-stack - Muhammad Ibtisam 🚀\033[0m\n"
echo -e "\033[1;32m💡 Automation is not about replacing humans; it's about freeing them to be more human—to create, innovate, and lead. \033[0m\n"
