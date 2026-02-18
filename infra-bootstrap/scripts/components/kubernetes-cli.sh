#!/usr/bin/env bash

# infra-bootstrap — Kubernetes CLI Toolchain Installer
# ----------------------------------------------------
# Installs kubectl, helm, kustomize, and k9s on Linux.

set -e
set -o pipefail

trap 'echo -e "\n\033[1;31m❌ Error occurred at line $LINENO\033[0m\n" && exit 1' ERR

PAD=16
REPO_URL="https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/system-checks"

# --------------------------- UI Helpers ---------------------------
section() {
  echo -e "\n\033[1;36m[INFO]    $1\033[0m"
}

info() {
  echo -e "\033[1;36m[INFO]    $1\033[0m"
}

ok() {
  echo -e "\033[1;32m[ OK ]    $1\033[0m"
}

error() {
  echo -e "\033[1;31m[ERROR]   $1\033[0m"
  exit 1
}

blank() {
  echo ""
}

# --------------------------- Header ---------------------------
echo -e "\n╔════════════════════════════════════════════════════════╗"
echo -e   "║ infra-bootstrap — Kubernetes CLI Toolchain            ║"
echo -e   "╚════════════════════════════════════════════════════════╝"

# --------------------------- Preflight ---------------------------
section "Running preflight checks..."
if bash <(curl -fsSL "https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/system-checks/preflight.sh") >/dev/null 2>&1; then
  ok "Preflight passed."
else
  error "Preflight failed — aborting."
fi
blank

# --------------------------- Utility: Latest Release Fetcher ---------------------------
get_latest_release() {
  curl -sL "https://api.github.com/repos/$1/releases/latest" | grep '"tag_name"' | cut -d '"' -f 4
}

# Extract architecture for assets
ARCH=$(uname -m)
[[ $ARCH == "x86_64" ]] && ARCH="amd64"

# --------------------------- Utility: Get Asset URL ---------------------------
get_asset_url() {
  REPO="$1"
  curl -sL "https://api.github.com/repos/$REPO/releases/latest" \
    | grep "browser_download_url" \
    | grep -i "$ARCH" \
    | grep -E "\.tar\.gz|\.tgz|\.zip|linux" \
    | cut -d '"' -f 4 \
    | head -n 1
}

# --------------------------- Utility: Download + Install ---------------------------
download_and_install() {
  URL="$1"
  TARGET="$2"

  TMP=$(mktemp -d)
  cd "$TMP"

  FILE=$(basename "$URL")
  curl -sLO "$URL" || error "Failed to download $FILE"

  if [[ $FILE == *.tar.gz || $FILE == *.tgz ]]; then
    tar -xzf "$FILE" || error "Extraction failed"
  elif [[ $FILE == *.zip ]]; then
    unzip "$FILE" >/dev/null 2>&1 || error "Extraction failed"
  fi

  BIN=$(find . -type f -perm -u+x | head -n 1)
  [[ -z "$BIN" ]] && error "Binary not found in archive"

  sudo mv "$BIN" "$TARGET"
  sudo chmod +x "$TARGET"

  cd - >/dev/null
  rm -rf "$TMP"
}

# ===================================================================
#                           Install kubectl
# ===================================================================
section "Installing kubectl..."
if command -v kubectl >/dev/null 2>&1; then
  KUBECTL_V=$(kubectl version --client -o yaml 2>/dev/null | grep gitVersion | sed 's/.*: v//' || echo "")
  ok "kubectl already installed"
else
  KUBECTL_V=$(curl -sL https://dl.k8s.io/release/stable.txt | sed 's/^v//')
  info "Latest kubectl: $KUBECTL_V"
  curl -sLO "https://dl.k8s.io/release/v${KUBECTL_V}/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/kubectl
  ok "kubectl installed"
fi
blank

# ===================================================================
#                           Install helm
# ===================================================================
section "Installing helm..."
if command -v helm >/dev/null 2>&1; then
  HELM_V=$(helm version --short 2>/dev/null | cut -d'+' -f1 | sed 's/^v//')
  ok "helm already installed"
else
  HELM_TAG=$(get_latest_release "helm/helm" | sed 's/^v//')
  info "Latest helm: $HELM_TAG"
  ASSET_URL="https://get.helm.sh/helm-v${HELM_TAG}-linux-amd64.tar.gz"

  TMP=$(mktemp -d)
  cd "$TMP"
  curl -sLO "$ASSET_URL"
  tar -xzf *.tar.gz
  sudo mv linux-amd64/helm /usr/local/bin/helm
  cd - >/dev/null
  rm -rf "$TMP"

  HELM_V="$HELM_TAG"
  ok "helm installed"
fi
blank

# ===================================================================
#                         Install kustomize
# ===================================================================
section "Installing kustomize..."
if command -v kustomize >/dev/null 2>&1; then
  KUSTOMIZE_V=$(kustomize version 2>/dev/null | grep -Eo 'v[0-9]+\.[0-9]+\.[0-9]+' | sed 's/^v//' || echo "")
  ok "kustomize already installed"
else
  KUSTOMIZE_TAG=$(get_latest_release "kubernetes-sigs/kustomize" | sed 's/^kustomize\///')
  info "Latest kustomize: $KUSTOMIZE_TAG"

  ASSET_URL=$(curl -sL "https://api.github.com/repos/kubernetes-sigs/kustomize/releases/latest" \
              | grep browser_download_url \
              | grep linux_amd64 \
              | head -n 1 \
              | cut -d '"' -f 4)

  download_and_install "$ASSET_URL" "/usr/local/bin/kustomize"

  KUSTOMIZE_V="$KUSTOMIZE_TAG"
  ok "kustomize installed"
fi
blank

# ===================================================================
#                           Install k9s
# ===================================================================
section "Installing k9s..."

# Detect whether k9s binary is actually runnable
if command -v k9s >/dev/null 2>&1 && file "$(command -v k9s)" | grep -q "x86-64"; then
    
    K9S_V=$(k9s version --short 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
    ok "k9s already installed"

else
    info "k9s not installed or wrong architecture — reinstalling"

    # Fetch correct asset
    ASSET_URL=$(curl -sL "https://api.github.com/repos/derailed/k9s/releases/latest" \
                 | grep "browser_download_url" \
                 | grep -i "k9s_Linux_${ARCH}.tar.gz" \
                 | head -n1 | cut -d '"' -f 4)

    [[ -n "${ASSET_URL:-}" ]] || error "Could not find k9s Linux_${ARCH} release asset."

    TMP=$(mktemp -d)
    cd "$TMP"

    curl -sLO "$ASSET_URL" || error "Failed to download k9s tarball"
    tar -xzf k9s*Linux* || error "Failed to extract k9s archive"

    BIN=$(find . -type f -name k9s -perm -u+x | head -n1)
    [[ -n "$BIN" ]] || error "Extracted archive does not contain k9s binary!"

    sudo mv "$BIN" /usr/local/bin/k9s
    sudo chmod +x /usr/local/bin/k9s

    cd - >/dev/null
    rm -rf "$TMP"

    K9S_V=$(k9s version --short 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
    ok "k9s installed (version: ${K9S_V:-unknown})"
fi
blank


# ===================================================================
#                              Summary
# ===================================================================
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf " • %-*s %s\n" "$PAD" "kubectl:"   "$KUBECTL_V"
printf " • %-*s %s\n" "$PAD" "helm:"      "$HELM_V"
printf " • %-*s %s\n" "$PAD" "kustomize:" "$KUSTOMIZE_V"
printf " • %-*s %s\n" "$PAD" "k9s:"       "$K9S_V"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ok "Kubernetes CLI toolchain ready"
blank