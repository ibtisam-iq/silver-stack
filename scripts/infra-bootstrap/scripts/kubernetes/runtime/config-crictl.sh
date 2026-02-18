#!/usr/bin/env bash
# ==================================================
# infra-bootstrap — Configure crictl
#
# Purpose:
#   - Explicitly configure CRI runtime endpoints
#   - Ensure crictl works reliably with containerd
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

# ───────────────────────── Configuration ─────────────────────────
CRICTL_CONFIG="/etc/crictl.yaml"
RUNTIME_ENDPOINT="unix:///run/containerd/containerd.sock"
IMAGE_ENDPOINT="unix:///run/containerd/containerd.sock"

# ───────────────────────── Preflight ─────────────────────────
info "Configuring crictl"

command -v crictl >/dev/null 2>&1 || error "crictl is not installed"
[[ -S /run/containerd/containerd.sock ]] || error "containerd socket not found"

# ───────────────────────── Write Config ─────────────────────────
info "Writing crictl configuration to ${CRICTL_CONFIG}"

cat >"$CRICTL_CONFIG" <<EOF
runtime-endpoint: ${RUNTIME_ENDPOINT}
image-endpoint: ${IMAGE_ENDPOINT}
timeout: 10
debug: false
pull-image-on-create: false
EOF

# ───────────────────────── Validation ─────────────────────────
info "Validating crictl configuration"

crictl info >/dev/null \
  || error "crictl failed to communicate with containerd"

ok "crictl configured successfully"
blank