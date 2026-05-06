#!/bin/bash

# 📌 Description:
# This script automates the initialization of the first Kubernetes control plane node.
# It assumes that the node is already running and has the necessary dependencies installed.
# The script will configure the node as a Kubernetes control plane node and start the necessary services.

set -e  # Exit immediately if a command fails
set -o pipefail  # Ensure failures in piped commands are detected

# Function to handle script failures
trap 'echo -e "\n❌ Error occurred at line $LINENO. Exiting...\n" && exit 1' ERR

# 🔧 System Configuration
echo -e "\n\033[1;33m🔧 Disabling swap...\033[0m"
sudo swapoff -a
if grep -q 'swap' /etc/fstab; then
    sudo sed -i '/\s\+swap\s\+/d' /etc/fstab
    echo -e "\033[1;32m✅ Swap entry removed from /etc/fstab.\033[0m"
else
    echo -e "\033[1;32m✅ No swap entry found in /etc/fstab.\033[0m"
fi

# Pull Kubernetes images
echo -e "\n\033[1;33m📥 Pulling required Kubernetes images...\033[0m"
sudo kubeadm config images pull || { echo -e "\n\033[1;31m❌ Failed to pull Kubernetes images. Exiting...\033[0m"; exit 1; }
echo -e "\033[1;32m✅ Kubernetes images pulled successfully.\033[0m".

echo -e "\n\033[1;36m🔗 Fetching cluster environment variables...\033[0m"

# ✅ Dynamically source cluster-params.sh
eval "$(curl -sL https://raw.githubusercontent.com/ibtisam-iq/silver-stack/main/scripts/kubernetes/cluster-params.sh)"

echo -e "🧠 CONTROL_PLANE_IP: \033[1;33m$CONTROL_PLANE_IP\033[0m"
echo -e "🖥️ NODE_NAME: \033[1;33m$NODE_NAME\033[0m"
echo -e "📦 POD_CIDR: \033[1;33m$POD_CIDR\033[0m"
echo -e "🔖 K8S_VERSION: \033[1;33m$K8S_VERSION\033[0m"

# Initialize Kubernetes control plane
echo -e "\n\033[1;34m🚀 Initializing Kubernetes control plane...\033[0m"
echo
sudo kubeadm init \
  --control-plane-endpoint "${CONTROL_PLANE_IP}:6443" \
  --upload-certs \
  --pod-network-cidr "${POD_CIDR}" \
  --apiserver-advertise-address="${CONTROL_PLANE_IP}" \
  --node-name "${NODE_NAME}" \
  --cri-socket=unix:///var/run/containerd/containerd.sock || { echo -e "\n\033[1;31m❌ kubeadm init failed. Exiting...\033[0m"; exit 1; }

# Total duration: 5 minutes (300 seconds)
DURATION=$((1 * 60))
INTERVAL=15
END_TIME=$((SECONDS + DURATION))

echo -e "\n\033[1;36m🎉 kubeadm-init.sh script is completed!\033[0m"
echo -e "\n\033[1;33m📌 Please wait, the cluster is stabilizing... Good things take time! ⏳✨\033[0m"

QUOTES=(
    "🚀 **Your cluster is like a rocket—fueling up for launch!** Hold tight! 🛸"
    "💡 **Patience is not just waiting, but keeping a great attitude while waiting!** 😃"
    "🏗️ **Every strong system starts with a stable foundation. Kubernetes is no different!** 🏛️"
    "✨ **Your cluster is doing yoga—finding its inner peace before greatness!** 🧘"
    "🌱 **Growth takes time, but oh, the view from the top is worth it!** 🚀"
    "🕰️ **Good things come to those who wait…** and to those who run ‘kubectl get pods’! 😆"
    "💪 **Resilience is built in silence. Your cluster is becoming unstoppable!** 🔥"
    "😎 **Be like Kubernetes—always self-healing, always scaling!** 🔄"
    "🎯 **Mastery takes time, but every great engineer started here! Keep going!** 💙"
    "📈 **Success is not a straight line, but a rolling update! Keep upgrading!** 🔄"
)

while [ $SECONDS -lt $END_TIME ]; do
    RANDOM_QUOTE=${QUOTES[$RANDOM % ${#QUOTES[@]}]}
    echo -e "\n\033[1;32m$RANDOM_QUOTE\033[0m"
    sleep $INTERVAL
done

echo -e "\n\033[1;36m✅ The cluster should now be stable! 🎯 Time to deploy greatness! 🚀💪\033[0m"
