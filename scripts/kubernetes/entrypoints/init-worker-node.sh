#!/usr/bin/env bash
# ============================================================================
# infra-bootstrap — Initialize Kubernetes Worker Node
#
# ENTRYPOINT SCRIPT (curl | bash compatible)
#
# Responsibilities:
#   • Orchestrate worker-node bootstrap in strict order
#   • No user interaction
#   • No local file assumptions
#   • Fail fast on any error
#
# Expected inputs (exported earlier):
#   CONTROL_PLANE_IP
#   K8S_VERSION
#   NODE_NAME
#   POD_CIDR
#   CONTAINERD_INSTALL_METHOD
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

banner "Kubernetes — Initialize Node"

# ───────────────────────── Preflight (silent) ────────────────────────────────
info "Running system preflight..."

if run_remote_script "$PREFLIGHT_URL" "Preflight check"; then
  ok "Preflight passed."
else
  error "Preflight failed — node not suitable."
fi
blank

# ───────────────────────── Phase 1: Cluster Parameters ──────────────────────

info "Phase 1 — Importing cluster paramesters"
blank

source_remote_library "$K8S_BASE_URL/cluster/cluster-params.sh" "Fetch cluster parameters" || {
  error "Failed to load cluster parameters"
}
blank

info "Node initialization started"
info "Node name: $NODE_NAME"
info "Kubernetes version: $K8S_VERSION"
info "Node ip: $CONTROL_PLANE_IP"
info "Containerd method: $CONTAINERD_INSTALL_METHOD"
blank

# ───────────────────────── Phase 2: Node Preparation ────────────────────────
info "Phase 2 — Node preparation"

run_remote_script "$K8S_BASE_URL/node/disable-swap.sh" "Disable swap" || {
  error "Failed to disable swap"
}
run_remote_script "$K8S_BASE_URL/node/load-kernel-modules.sh" "Load kernel modules" || {
  error "Failed to load kernel modules"
}
run_remote_script "$K8S_BASE_URL/node/apply-sysctl.sh" "Apply sysctl settings" || {
  error "Failed to apply sysctl settings"
}
blank

# ───────────────────────── Phase 3: Container Runtime Prerequisites ─────────
info "Phase 3 — Container runtime prerequisites"

run_remote_script "$K8S_RUNTIME_URL/install-cni-binaries.sh" "CNI binaries install" || {
  error "Failed to install CNI binaries"
}
blank

run_remote_script "$K8S_RUNTIME_URL/install-crictl.sh" "crictl install" || {
  error "Failed to install crictl"
}
blank

# ───────────────────────── Phase 4: Container Runtime ───────────────────────
info "Phase 4 — Container runtime installation"

run_remote_script "$K8S_RUNTIME_URL/install-containerd.sh" "Containerd install" || {
  error "Failed to install containerd"
}
blank

run_remote_script "$K8S_RUNTIME_URL/config-crictl.sh" "crictl configuration" || {
  error "Failed to configure crictl"
}
blank

# ───────────────────────── Load version resolver ─────────────────────────
info "Resolving Kubernetes versions (environment context)"

source_remote_library "$VERSION_RESOLVER_URL" "Kubernetes version resolver" || {
  error "Failed to load Kubernetes version resolver"
}

info "Kubernetes version context resolved"
blank

# ───────────────────────── Phase 5: Kubernetes Components ───────────────────
info "Phase 5 — Kubernetes node components"

run_remote_script "$K8S_PACKAGES_URL/install-kubeadm-kubelet.sh" "Kubeadm & Kubelet install" || {
  error "Failed to install kubeadm & kubelet"
}
blank

# ───────────────────────── Final State ──────────────────────────────────────
ok "Worker node initialization completed successfully"
blank