#!/usr/bin/env bash
# ==================================================
# infra-bootstrap — Install kubelet & kubeadm
#
# Purpose:
#   - Install Kubernetes node components for WORKER nodes
#   - kubelet + kubeadm only (NO kubectl)
#
# Versioning:
#   - User provides MAJOR.MINOR (e.g. 1.35)
#   - Script resolves latest PATCH automatically (e.g. 1.35.0)
#
# Repository:
#   - Official Kubernetes pkgs.k8s.io
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

# ───────────────────────── Preflight ─────────────────────────
info "Kubernetes node components installation"
info "Components: kubelet, kubeadm"

#: "${K8S_VERSION:?K8S_VERSION is required (e.g. 1.35)}"

# Resolver exports:
#   K8S_MAJOR_MINOR
#   K8S_PATCH_VERSION
#   K8S_IMAGE_TAG
#   KUBE_PKG_VERSION

info "Kubernetes version requested: ${K8S_MAJOR_MINOR}"
info "Resolved patch version: ${K8S_PATCH_VERSION}"
info "Repository track: v${K8S_MAJOR_MINOR}"
info "Using Kubernetes package version: ${KUBE_PKG_VERSION}"

# ───────────────────────── Dependencies ─────────────────────────
info "Installing required system packages"

apt-get update -qq >/dev/null
apt-get install -yq ca-certificates curl gpg >/dev/null

# ───────────────────────── Kubernetes Repository ─────────────────────────
info "Adding Kubernetes APT repository (pkgs.k8s.io)"

install -m 0755 -d /etc/apt/keyrings

# Remove legacy repo if present
rm -f /etc/apt/sources.list.d/kubernetes.list 2>/dev/null || true

if [[ ! -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg ]]; then
  curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${K8S_MAJOR_MINOR}/deb/Release.key" \
    | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
fi

cat >/etc/apt/sources.list.d/kubernetes.sources <<EOF
Types: deb
URIs: https://pkgs.k8s.io/core:/stable:/v${K8S_MAJOR_MINOR}/deb/
Suites: /
Components:
Signed-By: /etc/apt/keyrings/kubernetes-apt-keyring.gpg
EOF

apt-get update -qq >/dev/null

# ───────────────────────── Install kubelet & kubeadm ─────────────────────────
info "Installing kubelet and kubeadm"

apt-get install -yq \
  --allow-downgrades \
  --allow-change-held-packages \
  kubelet="${KUBE_PKG_VERSION}" \
  kubeadm="${KUBE_PKG_VERSION}" \
  >/dev/null

# ───────────────────────── Hold Versions ─────────────────────────
info "Holding Kubernetes packages to prevent auto-upgrade"

apt-mark hold kubelet kubeadm >/dev/null

# ───────────────────────── Enable kubelet ─────────────────────────
info "Enabling kubelet service"

systemctl enable kubelet >/dev/null

# ───────────────────────── Validation ─────────────────────────
KUBELET_VERSION="$(kubelet --version | awk '{print $2}' | sed 's/^v//')"
KUBEADM_VERSION="$(kubeadm version -o short | sed 's/^v//')"

ok "Kubernetes node components installed successfully"
info "kubelet version: ${KUBELET_VERSION}"
info "kubeadm version: ${KUBEADM_VERSION}"

blank