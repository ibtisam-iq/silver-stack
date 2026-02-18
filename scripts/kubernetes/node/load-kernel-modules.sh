#!/usr/bin/env bash
# ==================================================
# infra-bootstrap — Load Kernel Modules for Kubernetes
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

info "Loading required kernel modules..."

# Persist module loading
cat <<EOF | tee /etc/modules-load.d/k8s.conf > /dev/null
overlay
br_netfilter
EOF

# Ensure modprobe is available
if ! command -v modprobe >/dev/null 2>&1; then
    info "Installing kmod (required for modprobe)..."
    apt-get update -qq >/dev/null
    apt-get install -yq kmod >/dev/null
fi

# Load modules immediately
modprobe overlay
modprobe br_netfilter

ok "Kernel modules loaded: overlay, br_netfilter"
blank
