#!/bin/bash

set -euo pipefail
trap 'echo -e "\n\033[1;31m❌ Error at line $LINENO. Exiting...\033[0m"; exit 1' ERR

set -e  # Exit immediately if a command fails
set -o pipefail  # Ensure failures in piped commands are detected

# Function to handle script failures
trap 'echo -e "\n❌ Error occurred at line $LINENO. Exiting...\n" && exit 1' ERR

# ==================================================
# Restarting Required Services
# ==================================================

# Ensure required services are running
echo -e "\n\033[1;33m🔍 Ensuring necessary services are running...\033[0m"
sudo systemctl start containerd kubelet || true
sudo systemctl enable containerd kubelet --now || true
for service in containerd kubelet; do
    echo -n "$service: "
    systemctl is-active "$service"
done

# echo -e "\n\033[1;32m kubelet is activating, because it's waiting for the API server (which kubeadm init starts)..\033[0m"
# Since kubeadm init is not run, and kubelet needs a valid configuration to work, it keeps crashing and restarting.

# ubuntu@ip-172-31-17-2:~$ systemctl is-active "kubelet"
# activating
