#!/usr/bin/env bash
# ==================================================
# infra-bootstrap — Install containerd (Binary-Managed)
#
# Method:
#   - Binary-based installation from upstream containerd releases
#   - Uses GitHub artifacts (no OS package manager)
#
# Note:
#   This method is NOT the default.
#   Package-managed installation is preferred for industry-standard setups.
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

# ───────────────────────── Intro ─────────────────────────
info "Container runtime installation"
info "Method: BINARY-MANAGED (advanced / explicit control)"
info "Source: containerd upstream GitHub releases"

# ───────────────────────── Configuration ─────────────────────────
CONTAINERD_VERSION="${CONTAINERD_VERSION:-2.2.0}"
TMP_DIR="/tmp/containerd-binary-install"

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  *)
    error "Unsupported architecture: $(uname -m)"
    ;;
esac

TARBALL="containerd-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz"
BASE_URL="https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}"
DOWNLOAD_URL="${BASE_URL}/${TARBALL}"
CHECKSUM_URL="${BASE_URL}/${TARBALL}.sha256sum"

# ───────────────────────── Preflight ─────────────────────────
command -v runc >/dev/null 2>&1 || error "runc not found (required before containerd)"

if command -v containerd >/dev/null 2>&1; then
  CURRENT_VERSION="$(containerd --version | awk '{print $3}' | sed 's/^v//')"
  ok "containerd already installed (${CURRENT_VERSION}) — skipping"
  exit 0
fi

mkdir -p "$TMP_DIR"

# ───────────────────────── Download ─────────────────────────
info "Downloading containerd binary tarball"
curl -fsSL "$DOWNLOAD_URL" -o "${TMP_DIR}/${TARBALL}" \
  || error "Failed to download containerd tarball"

info "Downloading checksum file"
curl -fsSL "$CHECKSUM_URL" -o "${TMP_DIR}/${TARBALL}.sha256sum" \
  || error "Failed to download containerd checksum"

# ───────────────────────── Verify ─────────────────────────
info "Verifying checksum"
(
  cd "$TMP_DIR"
  sha256sum -c "${TARBALL}.sha256sum" >/dev/null
) || error "Checksum verification failed"

ok "Checksum verified"

# ───────────────────────── Install ─────────────────────────
info "Installing containerd binaries to /usr/local"
tar -xzf "${TMP_DIR}/${TARBALL}" -C /usr/local \
  || error "Failed to extract containerd binaries"

# ───────────────────────── Cleanup ─────────────────────────
rm -rf "$TMP_DIR"

# ───────────────────────── Systemd Setup ─────────────────────────
info "Installing containerd systemd service"

# Only needed if install via binary method (package method already provides it).
cat >/etc/systemd/system/containerd.service <<'EOF'
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStart=/usr/local/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl enable containerd --now

blank
