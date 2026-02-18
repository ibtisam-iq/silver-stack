#!/usr/bin/env bash
# ==================================================
# infra-bootstrap — Install CNI Plugin Binaries
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
CNI_VERSION="${CNI_VERSION:-v1.9.0}"
CNI_DIR="/opt/cni/bin"
TMP_DIR="/tmp/cni-install"

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  *)
    error "Unsupported architecture: $(uname -m)"
    ;;
esac

TARBALL="cni-plugins-linux-${ARCH}-${CNI_VERSION}.tgz"
BASE_URL="https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}"
DOWNLOAD_URL="${BASE_URL}/${TARBALL}"
CHECKSUM_URL="${BASE_URL}/${TARBALL}.sha256"

# ───────────────────────── Preflight ─────────────────────────
info "Installing CNI plugins"
info "Version: ${CNI_VERSION}"
info "Architecture: ${ARCH}"

mkdir -p "$CNI_DIR" "$TMP_DIR"

# Idempotency check
if [[ -x "${CNI_DIR}/bridge" ]]; then
  ok "CNI plugins already installed — skipping"
  exit 0
fi

# ───────────────────────── Download ─────────────────────────
info "Downloading CNI plugins tarball"
curl -fsSL "$DOWNLOAD_URL" -o "${TMP_DIR}/${TARBALL}" \
  || error "Failed to download CNI plugins"

info "Downloading checksum"
curl -fsSL "$CHECKSUM_URL" -o "${TMP_DIR}/${TARBALL}.sha256" \
  || error "Failed to download checksum"

# ───────────────────────── Verify ─────────────────────────
info "Verifying checksum"
(
  cd "$TMP_DIR"
  sha256sum -c "${TARBALL}.sha256" >/dev/null
) || error "Checksum verification failed"
ok "Checksum verified"

# ───────────────────────── Install ─────────────────────────
info "Extracting CNI plugins"
tar -xzf "${TMP_DIR}/${TARBALL}" -C "$CNI_DIR" \
  || error "Failed to extract CNI plugins"

# ───────────────────────── Cleanup ─────────────────────────
rm -rf "$TMP_DIR"

# ───────────────────────── Validation ─────────────────────────
[[ -x "${CNI_DIR}/bridge" ]] || error "CNI plugin binaries not found after install"

ok "CNI plugin binaries installed successfully"
exit 0