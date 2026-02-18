#!/usr/bin/env bash
# ==================================================
# infra-bootstrap — Install runc (OCI Runtime)
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
RUNC_VERSION="${RUNC_VERSION:-v1.4.0}"
INSTALL_PATH="/usr/local/sbin/runc"
TMP_DIR="/tmp/runc-install"

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  *)
    error "Unsupported architecture: $(uname -m)"
    ;;
esac

BINARY="runc.${ARCH}"
BASE_URL="https://github.com/opencontainers/runc/releases/download/${RUNC_VERSION}"
DOWNLOAD_URL="${BASE_URL}/${BINARY}"
CHECKSUM_URL="${BASE_URL}/runc.sha256sum"

# ───────────────────────── Preflight ─────────────────────────
info "Installing runc (OCI runtime)"
info "Version: ${RUNC_VERSION}"
info "Architecture: ${ARCH}"

# Idempotency
if command -v runc >/dev/null 2>&1; then
  CURRENT_VERSION="$(runc --version | awk 'NR==1 {print $3}')"
  ok "runc already installed (${CURRENT_VERSION}) — skipping"
  exit 0
fi

mkdir -p "$TMP_DIR"

# ───────────────────────── Download ─────────────────────────
info "Downloading runc binary"
curl -fsSL "$DOWNLOAD_URL" -o "${TMP_DIR}/${BINARY}" \
  || error "Failed to download runc binary"

info "Downloading checksum file"
curl -fsSL "$CHECKSUM_URL" -o "${TMP_DIR}/runc.sha256sum" \
  || error "Failed to download runc checksum file"

# ───────────────────────── Verify ─────────────────────────
info "Verifying checksum"

EXPECTED_HASH="$(
  grep " ${BINARY}$" "${TMP_DIR}/runc.sha256sum" | awk '{print $1}'
)"

[[ -n "$EXPECTED_HASH" ]] || error "Checksum for ${BINARY} not found"

echo "${EXPECTED_HASH}  ${TMP_DIR}/${BINARY}" | sha256sum -c - >/dev/null \
  || error "Checksum verification failed"

ok "Checksum verified"

# ───────────────────────── Install ─────────────────────────
info "Installing runc to ${INSTALL_PATH}"
install -m 0755 "${TMP_DIR}/${BINARY}" "$INSTALL_PATH" \
  || error "Failed to install runc"

# ───────────────────────── Cleanup ─────────────────────────
rm -rf "$TMP_DIR"

# ───────────────────────── Validation ─────────────────────────
command -v runc >/dev/null 2>&1 || error "runc not found after installation"

ok "runc installed successfully"
