#!/usr/bin/env bash
# ============================================================================
# infra-bootstrap — Ensure Kubernetes Core Services
# Ensures containerd and kubelet are enabled and in expected state
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

# ───────────────────────── Ensure Kubernetes services ───────────────────────
info "Ensuring Kubernetes Core Services"

# ───────────────────────── Services to verify ───────────────────────────────
SERVICES=(
  containerd
  kubelet
)

(
  IFS=', '
  info "Required services: ${SERVICES[*]}"
)

blank

# ───────────────────────── Ensure services are enabled and started ──────────
for svc in "${SERVICES[@]}"; do
  info "Checking service: ${svc}"

  # Ensure enabled
  if systemctl is-enabled "$svc" >/dev/null 2>&1; then
    ok "${svc} is enabled"
  else
    warn "${svc} is not enabled — enabling now"
    systemctl enable "$svc" >/dev/null 2>&1 || error "Failed to enable ${svc}"
    ok "${svc} enabled"
  fi

  # Check and handle running state
  if systemctl is-active "$svc" >/dev/null 2>&1; then
    ok "${svc} is active"
  else
    if [[ "$svc" == "kubelet" ]]; then
      warn "${svc} is not active yet (expected before kubeadm init/join)"
      info "Starting ${svc} — it will crashloop until cluster initialization"
      systemctl start "$svc" >/dev/null 2>&1 || error "Failed to start ${svc}"
      ok "${svc} started (crashloop is normal at this stage)"
    else
      warn "${svc} is not running — starting"
      systemctl start "$svc" >/dev/null 2>&1 || error "Failed to start ${svc}"
      # Verify it actually started (for non-kubelet services)
      if systemctl is-active "$svc" >/dev/null 2>&1; then
        ok "${svc} is now running"
      else
        error "${svc} failed to start properly"
      fi
    fi
  fi

  blank
done

ok "Kubernetes core services ensured — node ready for kubeadm init/join"
blank

exit 0