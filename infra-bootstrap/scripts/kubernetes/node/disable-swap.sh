#!/usr/bin/env bash
# ==================================================
# infra-bootstrap — Disable Swap (Kubernetes Requirement)
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

info "Disabling swap (required by Kubernetes)..."

# Disable swap immediately
swapoff -a || warn "swapoff returned non-zero (swap may already be disabled)"

# Persist swap disable across reboots
if grep -qE '^\s*[^#].*\s+swap\s+' /etc/fstab; then
    sed -i '/\s\+swap\s\+/d' /etc/fstab
    ok "Swap entries removed from /etc/fstab"
else
    ok "No active swap entries found in /etc/fstab"
fi

ok "Swap disabled successfully"
blank