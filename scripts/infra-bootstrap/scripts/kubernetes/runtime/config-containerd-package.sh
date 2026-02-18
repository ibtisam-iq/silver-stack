#!/usr/bin/env bash
# ==================================================
# infra-bootstrap — Configure containerd for Kubernetes
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

info "Configuring containerd for Kubernetes"

CONFIG_FILE="/etc/containerd/config.toml"

# ───────────────────────── Preflight ─────────────────────────
command -v containerd >/dev/null 2>&1 || error "containerd not installed"

mkdir -p /etc/containerd

# ───────────────────────── Generate Default Config ─────────────────────────
info "Generating default containerd configuration"
containerd config default > "$CONFIG_FILE"

# ───────────────────────── Kubernetes Requirements ─────────────────────────
info "Enabling systemd cgroup driver"
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' "$CONFIG_FILE"

# ───────────────────────── Restart Service ─────────────────────────
info "Restarting containerd"
systemctl restart containerd

blank