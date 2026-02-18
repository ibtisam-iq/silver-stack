#!/bin/bash

# ───── OPTIONAL CLEAR SCREEN ─────
if [[ "$1" == "--clear" ]]; then
  clear
fi

# ╔═══════════════════════════════════╗
# │ infra-bootstrap – CNI Network Utility  │
# ╚═══════════════════════════════════╝

# ───── COLORS ─────
YELLOW="\e[93m"
CYAN="\e[96m"
GREEN="\e[92m"
RED="\e[91m"
BOLD="\e[1m"
RESET="\e[0m"

# ───── TRAP FOR CTRL+C ─────
trap 'echo -e "\n${RED}❌ Script interrupted. Exiting...${RESET}"; exit 1' INT

# ───── HEADER ─────
function print_header() {
  echo -e "${BOLD}${CYAN}infra-bootstrap – CNI Network Setup Utility${RESET}"
  echo
  echo -e "${CYAN}Author   : Muhammad Ibtisam Iqbal"
  echo -e "Version  : v1.0"
  echo -e "Repo     : https://github.com/ibtisam-iq/infra-bootstrap"
  echo -e "License  : MIT${RESET}\n"
}

# ───── CLEANUP OLD CNI RESIDUES ─────
function cleanup_old_cni() {
  echo -e "${CYAN}🧹 Removing previous CNI residues, it may take some time...${RESET}"

  kubectl get crd | grep tigera.io | awk '{print $1}' | xargs kubectl delete crd --force > /dev/null 2>&1
  kubectl get crd | grep calico | awk '{print $1}' | xargs kubectl delete crd --force > /dev/null 2>&1
  kubectl get crd | grep calico | awk '{print $1}' | xargs kubectl delete crd --force > /dev/null 2>&1
  kubectl delete crd --force adminnetworkpolicies.policy.networking.k8s.io baselineadminnetworkpolicies.policy.networking.k8s.io > /dev/null 2>&1 # installations.operator.tigera.io
  kubectl delete po -n calico-apiserver -l k8s-app=calico-apiserver --force
  kubectl delete ns calico-system tigera-operator calico-apiserver --force > /dev/null 2>&1
  # kubectl delete crd installations.operator.tigera.io --force > /dev/null 2>&1
  
  kubectl delete ns kube-flannel --force > /dev/null 2>&1

  kubectl delete clusterrole.rbac.authorization.k8s.io/weave-net \
    clusterrolebinding.rbac.authorization.k8s.io/weave-net > /dev/null 2>&1
  kubectl delete -n kube-system \
    serviceaccount/weave-net \
    role.rbac.authorization.k8s.io/weave-net \
    rolebinding.rbac.authorization.k8s.io/weave-net \
    daemonset.apps/weave-net > /dev/null 2>&1

  if [ -d /etc/cni/net.d ]; then
    sudo bash -c 'rm -rf /etc/cni/net.d/*'
  fi
  sudo rm -rf /etc/cni/net.d/
  sudo rm -rf /etc/cni/net.d/*
  
  if systemctl is-active --quiet kubelet; then
    sudo systemctl stop kubelet
  fi

  PATTERNS=("vxlan.calico" "flannel*" "cni0" "weave" "datapath" "vxlan*" "veth*")
  
  if ip a | grep -q datapath; then
    sudo apt-get install -y openvswitch-switch > /dev/null 2>&1
    sudo systemctl restart networkd-dispatcher.service unattended-upgrades.service
    sudo ip link set datapath down > /dev/null 2>&1
    sudo ovs-vsctl add-br datapath > /dev/null 2>&1
    sudo ovs-vsctl del-br datapath > /dev/null 2>&1
    sudo apt-get remove --purge openvswitch-switch > /dev/null 2>&1
    sudo apt-get autoremove > /dev/null 2>&1
    sleep 60
  fi

  for pattern in "${PATTERNS[@]}"; do
    regex="^${pattern//\*/.*}$"
    for iface in $(ip -o link show | awk -F': ' '{print $2}' | cut -d'@' -f1 | grep -E "$regex"); do
      echo -e "${YELLOW}Bringing down interface: $iface${RESET}"
      sudo ip link set "$iface" down > /dev/null 2>&1 || echo -e "${RED}⚠️ Could not bring down $iface${RESET}"
      sleep 5
      echo -e "${YELLOW}Deleting interface: $iface${RESET}"
      sudo ip link delete "$iface" > /dev/null 2>&1 || {
        echo -e "${YELLOW}⚠️ $iface could not be deleted immediately. Retrying after 10s ...${RESET}"
        sleep 10
        sudo ip link delete "$iface" > /dev/null 2>&1 || echo -e "${RED}❌ Failed to delete $iface, will delete automatically after a few minutes.${RESET}"
      }
    done
  done

  for ns in $(ip netns list | awk '{print $1}'); do
    echo -e "${YELLOW}🧹 Deleting namespace: $ns${RESET}"
    sudo ip netns delete "$ns" > /dev/null 2>&1 || echo -e "${RED}❌ Failed to delete $ns${RESET}"
  done

  if ip route | grep -q cni0; then
    sudo ip route flush table main
    sudo ip route flush cache
  fi

  sudo systemctl restart kubelet containerd systemd-networkd
  echo -e "${CYAN} Previous CNI Residues Cleaned.${RESET}\n"
}

# ───── CNI OPTIONS ─────
function print_cni_menu() {
  echo -e "${GREEN}🌐 Proceeding with Post-Initialization Steps...${RESET}"
  echo -e "${GREEN}→ CNI Network Setup and Cluster Verification${RESET}"
  echo
  echo -e "${CYAN}📡 Please select a CNI plugin to install:${RESET}"
  echo " 1 Calico  - Best for advanced policy and large-scale clusters"
  echo " 2 Flannel - Lightweight and simple (default for many demos)"
  echo " 3 Weave   - Secure encryption, great for small clusters"
  echo
}

# ───── CNI INSTALL ─────
function install_cni() {
  local name="$1"
  local url="$2"

  echo -e "${GREEN}🔌 Installing ${BOLD}$name${RESET}${GREEN} CNI...${RESET}"
  echo

  if curl -sL "$url" | bash; then
    echo -e "${GREEN}✅ $name CNI installed successfully. Verifying cluster in 60s...${RESET}"
  else
    echo -e "${RED}❌ Failed to install $name. Check your internet or script URL.${RESET}"
    exit 1
  fi
}

#  ───── CNI CHECK ─────
function restart_and_validate_cni() {
  echo -e "\n${CYAN}🔁 Restarting system services...${RESET}"
  sudo systemctl restart containerd kubelet

  echo -e "\n${BLUE}🔍 Validating CNI plugin installation...${RESET}"
  sleep 10
  sudo ls /opt/cni/bin/
  echo -e "\n${GREEN}✅ CNI plugins found.${RESET}" 
}

# ───── CLUSTER CHECK ─────
function verify_cluster() { 
  echo -e "\n⏳ Waiting 60 seconds for CNI to stabilize..."
  sleep 60
  echo -e "\n${CYAN}📁 CNI config files in /etc/cni/net.d/:${RESET}"
  echo
  sudo ls -l /etc/cni/net.d/
  echo -e "\n🔍 ${CYAN}Cluster Status:${RESET}\n"
  kubectl get nodes -o wide || echo -e "${RED}❌ Failed to get node status.${RESET}"
  echo
  kubectl get pods -A || echo -e "${RED}❌ Failed to get pod status.${RESET}"
  echo
}

# ───── MAIN FLOW ─────
function main() {
  print_header
  echo
  print_cni_menu
  echo
  read -p "Enter your choice [1-3]: " choice < /dev/tty
  echo
  cleanup_old_cni

  
  case "$choice" in
    1|"") install_cni "Calico"  "https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/kubernetes/calico-setup.sh" ;;
    2)     install_cni "Flannel" "https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/kubernetes/flannel-setup.sh" ;;
    3)     install_cni "Weave"   "https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/kubernetes/weave-setup.sh" ;;
    *)
      echo -e "${RED}⚠️ Invalid input. Defaulting to Calico.${RESET}"
      install_cni "Calico"  "https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/kubernetes/calico-setup.sh"
      ;;
  esac
  
  restart_and_validate_cni
  verify_cluster
}

main

# Functions:
# ─ print_header
# ─ cleanup_old_cni
# ─ print_cni_menu
# ─ install_cni_plugin
# ─ restart_and_validate_cni
# ─ verify_cluster_ready
# ─ main
