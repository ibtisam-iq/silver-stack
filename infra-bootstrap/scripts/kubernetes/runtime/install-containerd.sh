#!/usr/bin/env bash
# ==================================================
# infra-bootstrap — Containerd Runtime Installation
#
# Entry point script (curl | bash compatible)
#
# This script dispatches containerd installation
# based on a pre-selected method.
#
# Expected environment variable:
#   CONTAINERD_INSTALL_METHOD=package|binary
# ==================================================

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

# ───────────────────────── Validation ─────────────────────────
: "${CONTAINERD_INSTALL_METHOD:?CONTAINERD_INSTALL_METHOD is not set}"

info "Container runtime installation started"
info "Selected method: $CONTAINERD_INSTALL_METHOD"
blank

# ───────────────────────── Dispatcher ─────────────────────────
case "$CONTAINERD_INSTALL_METHOD" in
  package)
    info "Using package-managed containerd installation"
    blank

    run_remote_script "$K8S_RUNTIME_URL/install-containerd-package.sh" "Install containerd (package-managed)"
    run_remote_script "$K8S_RUNTIME_URL/config-containerd-package.sh" "Configure containerd (package-managed)"
    ;;
  
  binary)
    info "Using binary-managed containerd installation"
    blank

    run_remote_script "$K8S_RUNTIME_URL/install-runc.sh" "Install runc (binary-managed)"
    run_remote_script "$K8S_RUNTIME_URL/install-containerd-binary.sh" "Install containerd (binary-managed)"
    run_remote_script "$K8S_RUNTIME_URL/config-containerd-binary.sh" "Configure containerd (binary-managed)"
    ;;
  
  *)
    error "Invalid CONTAINERD_INSTALL_METHOD: $CONTAINERD_INSTALL_METHOD"
    ;;
esac

# ───────────────────────── Enable Service ─────────────────────────
info "Enabling containerd service"
systemctl enable containerd --now

# ───────────────────────── Final Validation ─────────────────────────
if systemctl is-active --quiet containerd; then
  ok "containerd service is running"
else
  error "containerd service is not running"
fi

CONTAINERD_VERSION="$(containerd --version 2>/dev/null | awk '{print $3}' | sed 's/^v//')"
RUNC_VERSION="$(runc --version 2>/dev/null | awk 'NR==1{print $3}')"

info "containerd version: ${CONTAINERD_VERSION:-unknown}"
info "runc version: ${RUNC_VERSION:-unknown}"
blank

ok "Containerd runtime installation completed successfully"