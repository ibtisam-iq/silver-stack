#!/usr/bin/env bash
# ============================================================================
# infra-bootstrap — CNI Installation Entrypoint
# ----------------------------------------------------------------------------
# Supported CNIs:
#   • Calico
#   • Flannel
#
# This script:
#   - Requires an existing Kubernetes cluster
#   - Supports ONLY Calico and Flannel
#   - Can remove ONLY Calico or Flannel
#   - Will NOT attempt to remove unknown CNIs
#
# Responsibilities:
#   - Verify cluster availability
#   - Ensure CNI binaries are installed
#   - Detect leftover CNI filesystem state
#   - Detect active Calico / Flannel pods
#   - Perform safe, operator-approved cleanup
#   - Install selected CNI
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

# ───────────────────────── Framework ready ──────────────────────────────────
info "Core library loaded. Ready to build safely and deliberately."
blank

# ───────────────────────── Execution context ────────────────────────────────
print_execution_user
confirm_sudo_execution

# ───────────────────────── Load ensure_kubeconfig lib ───────────────────────
source_remote_library "$ENSURE_KUBECONFIG_URL" "ensure_kubeconfig"

# ───────────────────────── Constants ────────────────────────────────────────
CNI_BIN_DIR="/opt/cni/bin"
CNI_CONFIG_DIR="/etc/cni/net.d"
CALICO_LABEL="k8s-app=calico-node"
FLANNEL_LABEL="app=flannel"

# ───────────────────────── Header & Disclaimer ──────────────────────────────
info "infra-bootstrap — CNI Installation"
blank

info "DISCLAIMER"
blank
echo "  • This script supports installation ONLY for the following CNIs:"
echo "      - Calico"
echo "      - Flannel"
blank
echo "  • It can REMOVE only Calico or Flannel."
echo "  • It will NOT remove or detect other CNIs."
echo "  • If another CNI is installed, this script is NOT suitable."
blank

read -rp "Press Enter to continue, or Ctrl+C to abort: " _ < /dev/tty
blank

# ───────────────────────── Phase 1: Cluster detection ───────────────────────
info "Verifying Kubernetes cluster availability..."

ensure_kubeconfig

if ! kubectl get ns kube-system &>/dev/null; then
  warn "No Kubernetes cluster detected."
  blank
  info "Please initialize the cluster first:"
  blank
  cmd "curl -fsSL $INIT_CONTROL_PLANE_URL | sudo bash"
  blank
  exit 1
fi

ok "Kubernetes cluster detected"
blank

# ───────────────────────── Phase 2: Ensure CNI binaries ─────────────────────
info "Checking CNI binaries directory..."

if [[ ! -d "$CNI_BIN_DIR" ]] || [[ -z "$(ls -A "$CNI_BIN_DIR" 2>/dev/null)" ]]; then
  warn "CNI binaries not found in $CNI_BIN_DIR"
  blank
  read -rp "Press Enter to install CNI binaries, or Ctrl+C to abort: " _ < /dev/tty
  blank
  run_remote_script "$K8S_RUNTIME_URL/install-cni-binaries.sh" "CNI binaries installer"
  blank
else
  ok "CNI binaries detected in $CNI_BIN_DIR"
fi
blank

# ───────────────────────── Phase 3: Detect CNI filesystem residue ───────────
info "Checking for leftover CNI configuration files..."

CNI_FS_RESIDUE=false

if compgen -G "$CNI_CONFIG_DIR/*.conf" > /dev/null || \
   compgen -G "$CNI_CONFIG_DIR/*.conflist" > /dev/null; then
  CNI_FS_RESIDUE=true
fi

#if [[ -d "$CNI_CONFIG_DIR" ]] && \
#   ls "$CNI_CONFIG_DIR"/*.conf "$CNI_CONFIG_DIR"/*.conflist &>/dev/null; then
#  CNI_FS_RESIDUE=true
#fi

if [[ "$CNI_FS_RESIDUE" == true ]]; then
  warn "CNI configuration files detected in $CNI_CONFIG_DIR"
  info "This may be leftover configuration from a previous installation."
  blank

  read -rp "Press Enter to remove CNI configuration files, or Ctrl+C to abort: " _ < /dev/tty
  blank

  rm -f "$CNI_CONFIG_DIR"/*.conf "$CNI_CONFIG_DIR"/*.conflist 2>/dev/null || true
  ok "CNI configuration files removed"
  blank
else
  ok "No CNI filesystem residue detected at: $CNI_CONFIG_DIR"
  blank
fi

# ───────────────────────── Phase 4: Detect active CNI pods ──────────────────
info "Checking for active CNI pods..."

# Detect both CNIs independently

FOUND_CALICO=false
FOUND_FLANNEL=false

if kubectl -n calico-system get ds calico-node &>/dev/null; then
  FOUND_CALICO=true
fi

if kubectl -n kube-flannel get ds kube-flannel-ds &>/dev/null; then
  FOUND_FLANNEL=true
fi

# Decide what to reset (no guessing)

if [[ "$FOUND_CALICO" == false && "$FOUND_FLANNEL" == false ]]; then
  ok "No active supported CNI detected"
  blank
else
  warn "Existing CNI detected"
  blank

  if [[ "$FOUND_CALICO" == true ]]; then
    echo "  • Calico detected"
  fi

  if [[ "$FOUND_FLANNEL" == true ]]; then
    echo "  • Flannel detected"
  fi

  blank

  if ! confirm_or_abort "Type 'YES' to reset detected CNI components"; then
    warn "CNI reset aborted by operator"
    exit 0
  fi
  blank
fi

# Reset only what exists

if [[ "$FOUND_CALICO" == true ]]; then
  info "Resetting Calico CNI..."
  run_remote_script "$K8S_MAINTENANCE_URL/reset-calico.sh" "Reset Calico"
  ok "Calico reset completed"
  blank
fi

if [[ "$FOUND_FLANNEL" == true ]]; then
  info "Resetting Flannel CNI..."
  run_remote_script "$K8S_MAINTENANCE_URL/reset-flannel.sh" "Reset Flannel"
  ok "Flannel reset completed"
  blank
fi

# ───────────────────────── Phase 5: CNI selection & install ─────────────────
while true; do
  info "Select CNI plugin to install"
  blank
  echo "  1) Calico (default)"
  echo "  2) Flannel"
  echo "  0) Exit"
  blank

  read -rp "Enter your choice [1]: " CHOICE _ < /dev/tty
  blank

  CHOICE="${CHOICE:-1}"

  case "$CHOICE" in
    1)
      info "Installing Calico..."
      run_remote_script "$INSTALL_CALICO_URL" "Install Calico"
      break
      ;;
    2)
      info "Installing Flannel..."
      run_remote_script "$INSTALL_FLANNEL_URL" "Install Flannel"
      break
      ;;
    0)
      info "Exiting CNI installer"
      exit 0
      ;;
    *)
      warn "Invalid selection. Please try again."
      blank
      ;;
  esac
done

blank
ok "CNI installation flow completed successfully"
exit 0
