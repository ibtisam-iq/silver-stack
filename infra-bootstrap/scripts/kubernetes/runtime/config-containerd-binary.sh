#!/usr/bin/env bash
# ==================================================
# infra-bootstrap — Configure containerd for Kubernetes (containerd v2.2.0)
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
CONTAINERD_CONFIG="/etc/containerd/config.toml"
CONTAINERD_SOCKET="/run/containerd/containerd.sock"
SANDBOX_IMAGE="${SANDBOX_IMAGE:-registry.k8s.io/pause:3.9}"  # Safe stable tag; update if needed
CNI_BIN_DIR="/opt/cni/bin"
CNI_CONF_DIR="/etc/cni/net.d"

# ───────────────────────── Preflight Checks ─────────────────────────
info "Configuring containerd for Kubernetes"
command -v containerd >/dev/null || error "containerd not installed"
command -v runc >/dev/null || error "runc not installed"
[[ -d "$CNI_BIN_DIR" ]] || error "CNI binaries directory not found: $CNI_BIN_DIR"
mkdir -p /etc/containerd "$CNI_CONF_DIR"

# ───────────────────────── Generate Base Config ─────────────────────────
info "Generating default containerd configuration"
containerd config default > "$CONTAINERD_CONFIG" \
  || error "Failed to generate default config"

# ───────────────────────── Kubernetes-specific Tweaks ─────────────────────────
info "Applying Kubernetes CRI tweaks"

# Enable systemd cgroups (critical!)
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' "$CONTAINERD_CONFIG"

# Set pause (sandbox) image
sed -i "s#sandbox_image = \".*\"#sandbox_image = \"${SANDBOX_IMAGE}\"#" "$CONTAINERD_CONFIG"

# Set CNI paths (bin_dir is still supported; bin_dirs array is optional/future)
sed -i "s#bin_dir = \".*\"#bin_dir = \"${CNI_BIN_DIR}\"#" "$CONTAINERD_CONFIG"
sed -i "s#conf_dir = \".*\"#conf_dir = \"${CNI_CONF_DIR}\"#" "$CONTAINERD_CONFIG"

# ───────────────────────── Restart & Validate ─────────────────────────
info "Restarting containerd service"
systemctl restart containerd || error "Failed to restart containerd"

info "Waiting for containerd socket"
for i in {1..10}; do
  [[ -S "$CONTAINERD_SOCKET" ]] && break
  sleep 1
done
[[ -S "$CONTAINERD_SOCKET" ]] || error "containerd socket not available"
ok "containerd configured and running"

info "Validating CRI plugin"
crictl info >/dev/null 2>&1 || error "CRI validation failed"
ok "CRI plugin functional"
blank