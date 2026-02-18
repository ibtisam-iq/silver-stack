#!/usr/bin/env bash
# ============================================================================
# infra-bootstrap — Kubernetes Existing State Detection
# ----------------------------------------------------------------------------
# Purpose:
#   Detect existing Kubernetes cluster or leftover node state and prevent
#   unsafe kubeadm init execution.
#
# Behavior:
#   • Strong indicators  → block & offer full kubeadm reset
#   • Weak indicators    → offer targeted cleanup
#   • No indicators      → proceed silently
# ============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

# ───────────────────────── Parse DRY RUN flag ───────────────────────────────
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --dry-run)
      DRY_RUN=1
      ;;
  esac
done

export DRY_RUN

# ───────────────────────── Load common library (bootstrap) ──────────────────
LIB_URL="https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/lib/common.sh"

TMP_LIB="$(mktemp -t infra-bootstrap-XXXXXXXX.sh)"
curl -fsSL "$LIB_URL" -o "$TMP_LIB" || {
  echo "FATAL: Unable to download common.sh from $LIB_URL"
  exit 1
}

source "$TMP_LIB" || {
  echo "FATAL: Unable to source common.sh"
  rm -f "$TMP_LIB"
  exit 1
}

rm -f "$TMP_LIB"

# ───────────────────────── Root requirement ─────────────────────────────────
require_root

# ───────────────────────── Internal State ───────────────────────────────────
STRONG_FOUND=false          # Active cluster indicators, kubeadm init will fail. kubeadm reset offered.
WEAK_FOUND=false            # Leftover state indicators, targeted cleanup offered.

declare -a STRONG_ITEMS=()
declare -a WEAK_ITEMS=()


# Presence implies an existing (or partially existing) control plane

K8S_STRONG_PATHS=(
  "/var/lib/etcd"
  "/etc/kubernetes/manifests/etcd.yaml"
  "/etc/kubernetes/manifests/kube-apiserver.yaml"
  "/etc/kubernetes/manifests/kube-scheduler.yaml"
  "/etc/kubernetes/manifests/kube-controller-manager.yaml"
)

# Presence implies leftover node state (not a running cluster)

K8S_WEAK_PATHS=(
  # "/opt/cni/bin"         # CNI binaries left behind (optional)
  # "/etc/cni/net.d"       # CNI configs (moved to CNI installer)
  "/var/lib/kubelet"  
  "/etc/kubernetes/pki"
  "/etc/kubernetes/admin.conf"
  "/home/${SUDO_USER:-$USER}/.kube"
)

# ───────────────────────── Ports (Strong) ───────────────────────────────────
K8S_PORTS=(
  6443
  2379
  2380
  10250
  10257
  10259
)

# ───────────────────────── Detect Strong Filesystem State ───────────────────
for path in "${K8S_STRONG_PATHS[@]}"; do
  if [[ -e "$path" ]]; then
    STRONG_FOUND=true
    STRONG_ITEMS+=("Control-plane artifact present at: $path")
  fi
done

# ───────────────────────── Detect Weak Filesystem State ─────────────────────
for path in "${K8S_WEAK_PATHS[@]}"; do
  if [[ -d "$path" ]] && [[ -n "$(ls -A "$path" 2>/dev/null)" ]]; then
    WEAK_FOUND=true
    WEAK_ITEMS+=("Leftover Kubernetes state found at: $path")
  fi
done

# ───────────────────────── Detect Ports (Strong) ────────────────────────────
for port in "${K8S_PORTS[@]}"; do
  if ss -ltnp 2>/dev/null | grep -q ":$port "; then
    PROC=$(ss -ltnp | grep ":$port " | head -n1 | sed 's/.*users:(//;s/).*//')
    STRONG_FOUND=true
    STRONG_ITEMS+=("Kubernetes port $port in use → $PROC")
  fi
done

# ───────────────────────── Decision Tree ────────────────────────────────────

# ── Case 1: Clean node ──────────────────────────────────────────────────────
if [[ "$STRONG_FOUND" == false && "$WEAK_FOUND" == false ]]; then
  ok "No existing Kubernetes cluster or leftover state detected"
  blank
  exit 0
fi

# ── Case 2: Strong indicators found ─────────────────────────────────────────
if [[ "$STRONG_FOUND" == true ]]; then
  warn "Existing Kubernetes cluster or partial control plane detected"
  blank

  info "Detected strong indicators:"
  blank
  for item in "${STRONG_ITEMS[@]}"; do
    echo "  • $item"
  done

  blank
  warn "This node is NOT safe for a fresh kubeadm init."
  blank

  info "Options:"
  blank
  echo "  1) Abort now and clean up manually"
  echo "  2) Press Enter to automatically reset the cluster (kubeadm reset)"
  blank

  read -rp "Press Enter to continue with automatic reset, or Ctrl+C to abort: " _ < /dev/tty || true
  blank

  blank
  info "Starting full Kubernetes cluster reset..."
  blank

  run_remote_script "$K8S_MAINTENANCE_URL/reset-cluster.sh" "Cluster reset"

  ok "Cluster reset completed successfully"
  blank
  exit 0
fi

# ── Case 3: Weak indicators only (leftovers) ────────────────────────────────
warn "Leftover Kubernetes node state detected (no active cluster)"
blank

info "Detected leftover state:"
blank
for item in "${WEAK_ITEMS[@]}"; do
  echo "  • $item"
done

blank
info "Proceeding without cleanup may cause kubeadm init to fail."
blank

info "Options:"
blank
echo "  1) Abort now and clean up manually"
echo "  2) Press Enter to remove leftover state and continue"
blank

read -rp "Press Enter to clean up leftover state, or Ctrl+C to abort: " _ < /dev/tty || true
blank

#if ! confirm_or_abort "Type 'YES' to confirm cleanup of leftover Kubernetes state"; then
#  blank
#  exit 0
#fi

blank
info "Cleaning up leftover Kubernetes state..."
blank

# Targeted cleanup (NO kubeadm reset)
rm -rf /var/lib/kubelet/*
rm -rf /home/${SUDO_USER:-$USER}/.kube 2>/dev/null || true
rm -rf /etc/kubernetes/pki/* 
rm -f /etc/kubernetes/admin.conf

ok "Leftover Kubernetes state removed"
blank

exit 0