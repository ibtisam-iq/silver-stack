#!/bin/bash

# 📌 Description:
# This script automates the deployment of the Flannel network plugin for Kubernetes.
# It fetches the official manifest, patches the Pod CIDR (if necessary), and applies the configuration.
# It assumes the Kubernetes cluster is already initialized and running.

set -e
set -o pipefail
trap 'echo -e "\n❌ Error occurred at line $LINENO. Exiting...\n" && exit 1' ERR

# 🔗 Fetch dynamic cluster environment variables
echo -e "\n\033[1;36m🔗 Fetching cluster environment variables...\033[0m"
eval "$(curl -sL https://raw.githubusercontent.com/ibtisam-iq/silver-stack/main/scripts/kubernetes/cluster-params.sh)"

echo -e "📦 POD_CIDR to be configured: $POD_CIDR"

# 🔄 Start Kubernetes services
curl -sL https://raw.githubusercontent.com/ibtisam-iq/silver-stack/main/scripts/kubernetes/k8s-start-services.sh | sudo bash

# ⬇️ Download the official Flannel manifest
echo -e "\n\033[1;34m📥 Downloading official Flannel manifest...\033[0m"
curl -LO https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

FILE="kube-flannel.yml"

# 🛠️ Patch the CIDR in net-conf.json
cp "$FILE" "${FILE}.bak"
sed -i "s#\"Network\": *\"[^\"]*\"#\"Network\": \"${POD_CIDR}\"#" "$FILE"
echo
echo "✅ CIDR updated to ${POD_CIDR} in $FILE"

# ℹ️ CIDR_RANGE explanation
# Network defines the CIDR block that Flannel uses to allocate pod IP addresses.
# If not explicitly set, it defaults to 10.244.0.0/16 in the official manifest.

# 📤 Apply the Flannel CNI configuration
echo -e "\n\033[1;34m🚀 Applying Flannel network configuration...\033[0m"
kubectl apply -f "$FILE" || { echo -e "\n\033[1;31m❌ Failed to apply Flannel CNI. Exiting...\033[0m"; exit 1; }

echo -e "\n\033[1;36m🎉 flannel-setup.sh script is completed!\033\n[0m"
