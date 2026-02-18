#!/usr/bin/env bash
# ============================================================================
# infra-bootstrap — Kubernetes Control Plane CLI Tools
# Installs: kubectl, helm, k9s
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

# ───────────────────────── Load version resolver ─────────────────────────

source_remote_library "$VERSION_RESOLVER_URL" "Kubernetes version resolver" || {  
  error "Failed to load Kubernetes version resolver"
}

# ============================================================================
# kubectl
# ============================================================================
blank
info "Kubernetes — Control Plane CLI Tools Installation"
blank
info "1) Installing kubectl..."

if command -v kubectl >/dev/null 2>&1; then
  KUBECTL_V="$(kubectl version --client -o yaml 2>/dev/null | grep gitVersion | sed 's/.*: v//' || echo "")"
  ok "kubectl already installed (${KUBECTL_V}) — skipping"
else
  info "Installing kubectl version: ${K8S_PATCH_VERSION}"
  apt-get install -yq \
    --allow-downgrades \
    --allow-change-held-packages \
    kubectl="${KUBE_PKG_VERSION}" \
    >/dev/null
  ok "kubectl installed"
fi 

blank

# ============================================================================
# helm
# ============================================================================
info "2) Installing Helm..."

if command -v helm >/dev/null 2>&1; then
  HELM_V="$(helm version --short 2>/dev/null | cut -d'+' -f1 | sed 's/^v//')"
  ok "Helm already installed (${HELM_V}) — skipping"
else
  info "Installing Helm 4 (silent)"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4 | bash >/dev/null \
    || error "Helm installation failed"

  ok "Helm installed"
fi

blank

# ============================================================================
# k9s
# ============================================================================
info "3) Installing k9s..."

K9S_VERSION="v0.50.16"
INSTALL_PATH="/usr/local/bin/k9s"
TMP_DIR="/tmp/k9s-install"

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  *)
    error "Unsupported architecture: $(uname -m)"
    ;;
esac

if command -v k9s >/dev/null 2>&1; then

  K9S_V=$(k9s version --short 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
  info "k9s already installed (${K9S_V}) — skipping"

else
  info "Version: ${K9S_VERSION#v}"
  info "Architecture: ${ARCH}"

  mkdir -p "$TMP_DIR"
  TARBALL="k9s_Linux_${ARCH}.tar.gz"
  DOWNLOAD_URL="https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/${TARBALL}"

  info "Downloading k9s"
  curl -fsSL "$DOWNLOAD_URL" -o "${TMP_DIR}/${TARBALL}" \
    || error "Failed to download k9s"

  info "Extracting k9s"
  tar -xzf "${TMP_DIR}/${TARBALL}" -C "$TMP_DIR" \
    || error "Failed to extract k9s"

  install -m 0755 "${TMP_DIR}/k9s" "$INSTALL_PATH" \
    || error "Failed to install k9s"

  rm -rf "$TMP_DIR"
  ok "k9s installed"
fi

blank

# ============================================================================
# Summary
# ============================================================================
PAD=16
item_ver() { printf " %b•%b %-*s %s\n" "$C_CYAN" "$C_RESET" "$PAD" "$1:" "$2"; }

KUBECTL_V="$(kubectl version --client -o yaml 2>/dev/null | grep gitVersion | sed 's/.*: v//' || echo "")"
HELM_V="$(helm version --short 2>/dev/null | cut -d'+' -f1 | sed 's/^v//')"
K9S_V="$(k9s version --short 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"


item_ver "kubectl"   "${KUBECTL_V:-unknown}"
item_ver "helm"      "${HELM_V:-unknown}"
item_ver "k9s"       "${K9S_V:-unknown}"
blank

ok "Control plane CLI tooling ready"
blank

exit 0