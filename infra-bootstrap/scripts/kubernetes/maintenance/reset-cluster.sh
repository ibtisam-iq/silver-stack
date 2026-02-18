#!/usr/bin/env bash
# ============================================================================
# infra-bootstrap — Kubernetes Cluster Cleanup (DESTRUCTIVE)
# ----------------------------------------------------------------------------
# Purpose:
#   Fully reset and clean a Kubernetes node that was initialized with kubeadm.
#
# WARNING:
#   • THIS SCRIPT IS DESTRUCTIVE
#   • ALL Kubernetes state will be permanently deleted
#   • Intended for lab, rebuild, or re-provisioning scenarios ONLY
#
# Behavior:
#   • Uses kubeadm reset as the primary cleanup mechanism
#   • Stops services cleanly (no pkill, no fuser hacks)
#   • Removes residual directories kubeadm does not own
#
# Exit codes:
#   0 → Cleanup completed
#   1 → Aborted by user
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

warn "THIS OPERATION IS DESTRUCTIVE."
warn "All Kubernetes data, certificates, and state will be permanently removed."
blank

confirm_or_abort "Type 'YES' to confirm full cluster destruction" || exit 0
blank

# ───────────────────────── Stop services cleanly ────────────────────────────
info "Stopping Kubernetes Services"

SERVICES=(
  kubelet           # kubelet must be stopped before reset
  # containerd      # CRI must be running during reset
)

for svc in "${SERVICES[@]}"; do
  if systemctl is-active --quiet "$svc"; then
    info "Stopping $svc"
    systemctl stop "$svc"
  else
    info "$svc already stopped"
  fi
done

blank

# ───────────────────────── kubeadm reset (authoritative) ────────────────────
info "Running kubeadm reset"

if command -v kubeadm &>/dev/null; then
  kubeadm reset -f
  ok "kubeadm reset completed"
else
  warn "kubeadm not found — skipping reset"
fi

blank

# ───────────────────────── Remove residual directories ──────────────────────
info "Removing Residual Kubernetes State"

PATHS=(
  /etc/kubernetes
  /var/lib/kubelet
  /var/lib/etcd
  "/home/${SUDO_USER:-$USER}/.kube"
)

for path in "${PATHS[@]}"; do
  if [[ -e "$path" ]]; then
    info "Removing $path"
    rm -rf "$path"
  else
    info "Not present: $path"
  fi
done

blank

# ───────────────────────── Orphaned kube-apiserver ────────────────────────
# This can happen if containerd was stopped before running kubeadm reset1
info "Orphaned kube-apiserver Check"

if ss -ltnp | grep -q ':6443'; then
  warn "Detected orphaned kube-apiserver process"
  warn "No CRI ownership detected — terminating process"
  PID=$(ss -ltnp | awk '/:6443/ {print $NF}' | sed 's/.*pid=//;s/,.*//')
  kill "$PID" || kill -9 "$PID"
  ok "Orphaned kube-apiserver terminated"
  blank
fi

# ───────────────────────── Container runtime state ────────────────────────

info "Container Runtime State"
systemctl stop containerd

info "containerd left stopped intentionally"
info "It will be started by the next bootstrap phase"

ok "Kubernetes cleanup completed successfully"
exit 0
blank