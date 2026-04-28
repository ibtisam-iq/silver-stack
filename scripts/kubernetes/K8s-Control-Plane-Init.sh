#!/bin/bash

if [[ "$1" == "--clear" ]]; then
  clear
fi

# Define Colors
YELLOW="\e[93m"
CYAN="\e[96m"
GREEN="\e[92m"
RED="\e[91m"
BOLD="\e[1m"
RESET="\e[0m"

# Header Display
echo -e "${YELLOW}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║    ███████╗██╗██╗     ██╗   ██╗███████╗██████╗ ██╗████████╗ ║"
echo "║    ██╔════╝██║██║     ██║   ██║██╔════╝██╔══██╗██║╚══██╔══╝ ║"
echo "║    █████╗  ██║██║     ██║   ██║█████╗  ██████╔╝██║   ██║    ║"
echo "║    ██╔══╝  ██║██║     ██║   ██║██╔══╝  ██╔═══╝ ██║   ██║    ║"
echo "║    ██║     ██║███████╗╚██████╔╝███████╗██║     ██║   ██║    ║"
echo "║    ╚═╝     ╚═╝╚══════╝ ╚═════╝ ╚══════╝╚═╝     ╚═╝   ╚═╝    ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"
echo -e "${BOLD}${CYAN}               Kubernetes Control Plane Bootstrapper${RESET}\n"

# Info Block
echo -e "${CYAN}───────────────────────────────────────────────────────────────${RESET}"
echo -e "${BOLD}silver-stack – Kubernetes Bootstrap Utility${RESET}"
echo -e "${CYAN}Author   : Muhammad Ibtisam Iqbal${RESET}"
echo -e "${CYAN}Version  : v1.0${RESET}"
echo -e "${CYAN}Repo     : https://github.com/ibtisam-iq/silver-stack${RESET}"
echo -e "${CYAN}License  : MIT${RESET}"
echo -e "${CYAN}───────────────────────────────────────────────────────────────${RESET}"

echo
echo -e "${GREEN}🧊 Initializing your Kubernetes Control Plane...${RESET}"
echo

# 📌 Description:
# This script automates the initialization of the first Kubernetes control plane node.
#
# 🚀 Usage:
#   curl -sL https://raw.githubusercontent.com/ibtisam-iq/silver-stack/main/scripts/kubernetes/K8s-Control-Plane-Init.sh | sudo bash

set -euo pipefail
trap 'echo -e "\n\033[1;31m❌ Error at line $LINENO. Exiting...\033[0m"; exit 1' ERR

REPO_URL="https://raw.githubusercontent.com/ibtisam-iq/silver-stack/main/scripts/kubernetes/"

# List of scripts to execute
SCRIPTS=(
    "K8s-Node-Init.sh"
    "k8s-cleanup.sh"
    "k8s-start-services.sh"
    "kubeadm-init.sh"
    "kube-config-setup.sh"
)

# 🚀 Executing Scripts
for script in "${SCRIPTS[@]}"; do
    echo -e "\n${CYAN}▶️ Executing: ${script}...${RESET}"
    bash <(curl -fsSL "$REPO_URL/$script") || {
        echo -e "\n${RED}❌ Error: Failed to execute ${script}. Exiting.${RESET}\n"
        exit 1
    }
    echo -e "${GREEN}✅ Done: ${script}${RESET}\n"
done

echo -e "${CYAN}───────────────────────────────────────────────────────────────${RESET}"

# ==================================================
# 🎉 Final Messages
# ==================================================
echo
echo -e "${GREEN}🎉 Cluster Initialized Successfully!${RESET}"
echo

echo -e "${BOLD}📋 Summary of What’s Done So Far:${RESET}"
echo -e "   ✅ Kubernetes control plane has been successfully initialized."
echo -e "   ✅ kubeconfig has been configured for the current user."
echo -e "   ✅ Cluster is now ready to accept and manage worker nodes."
echo

echo -e "${BOLD}🧩 Step 1 (Recommended): Join Worker Nodes${RESET}"
echo
echo -e "${CYAN}📌 The join command was printed by 'kubeadm init' above 👆.${RESET}"
echo -e "   Please copy that command and run it on each worker node to join the cluster."
echo -e "${YELLOW}⚠️ That token is time-sensitive. Use it within 24 hours or regenerate with:${RESET}"
echo -e "${YELLOW}   kubeadm token create --print-join-command${RESET}"
echo

echo -e "${BOLD}🌐 Final Setup Step – Deploy a CNI (Mandatory)${RESET}"
echo
echo -e "   Kubernetes requires a CNI plugin for pod networking and intercommunication."
echo -e "   You’ll be able to choose between Calico, Flannel, or Weave in the next step."
echo

echo -e "${RED}🔒 Important:${RESET}"
echo -e "${YELLOW}   ➤ CNI should be installed ONLY ON THE FIRST CONTROL PLANE NODE!${RESET}"
echo -e "${YELLOW}     Do NOT apply the network plugin on any additional control plane or worker node.${RESET}"
echo

echo -e "${BOLD}${GREEN}🚀 To complete the final setup step, run:${RESET}"
echo
echo -e "   ${GREEN}curl -sL https://raw.githubusercontent.com/ibtisam-iq/silver-stack/main/scripts/kubernetes/k8s-cni-setup.sh | bash${RESET}"
echo

echo -e "${CYAN}🛠️ This script will:${RESET}"
echo -e "   ─ Prompt you to select a CNI plugin"
echo -e "   ─ Deploy it seamlessly"
echo -e "   ─ Assist you in verifying that your Kubernetes cluster is fully operational"
echo

echo -e "${BOLD}${GREEN}🎯 Congratulations! You're just one step away from a complete Kubernetes cluster.${RESET}"
echo

echo -e "${CYAN}✨ Thank you for using ${BOLD}silver-stack${CYAN} – crafted with care by Muhammad Ibtisam!${RESET}"
echo -e "${CYAN}───────────────────────────────────────────────────────────────${RESET}"
echo
