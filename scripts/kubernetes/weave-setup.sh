#!/bin/bash

# 📌 Description:
# This script automates the deployment of the Weave network plugin for Kubernetes.
# It assumes that the Kubernetes cluster is already initialized and running.
# The script installs the Weave CNI and configures it using the dynamically sourced POD_CIDR.

set -e
set -o pipefail
trap 'echo -e "\n❌ Error occurred at line $LINENO. Exiting...\n" && exit 1' ERR

# 🔗 Fetch dynamic cluster environment variables
echo -e "\n\033[1;36m🔗 Fetching cluster environment variables...\033[0m"
eval "$(curl -sL https://raw.githubusercontent.com/ibtisam-iq/silver-stack/main/scripts/kubernetes/cluster-params.sh)"

echo -e "📦 POD_CIDR being configured: $POD_CIDR"
echo -e "🔖 WEAVE_VERSION being configured: \033[1;33m$K8S_VERSION\033[0m"

# 🔄 Start Kubernetes services
curl -sL https://raw.githubusercontent.com/ibtisam-iq/silver-stack/main/scripts/kubernetes/k8s-start-services.sh | sudo bash

# 🚀 Deploying Weave CNI
echo -e "\n\033[1;34m🚀 Deploying Weave network plugin...\033[0m"

# 📤 Apply the Weave manifest
kubectl apply -f "https://reweave.azurewebsites.net/k8s/v${K8S_VERSION}/net.yaml?env.IPALLOC_RANGE=${POD_CIDR}" || { echo -e "\n\033[1;31m❌ Failed to apply Weave CNI. Exiting...\033[0m"; exit 1; }
# IPALLOC_RANGE defines the CIDR block that Weave Net uses to allocate pod IP addresses.
# If not explicitly set, it defaults to 10.32.0.0/12.

echo -e "\n\033[1;32m✅ Weave network plugin deployed successfully.\033[0m"
echo -e "\n\033[1;36m🎉 weave-setup.sh script is completed!\033\n[0m"
