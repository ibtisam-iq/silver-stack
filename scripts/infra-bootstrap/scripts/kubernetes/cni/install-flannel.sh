#!/usr/bin/env bash
# ============================================================================
# infra-bootstrap — Install Flannel CNI
# ----------------------------------------------------------------------------
# Installs Flannel using cluster-derived Pod CIDR.
#
# Characteristics:
#   - curl | bash safe
#   - No environment variable dependency
#   - Pod CIDR detected from cluster (source of truth)
#   - Latest Flannel release
#   - Config patched before apply
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

# ──────────────────────── Load ensure_kubeconfig ────────────────────────────
source_remote_library "$ENSURE_KUBECONFIG_URL" "ensure_kubeconfig"

# ───────────────────────── Constants ────────────────────────────────────────
FLANNEL_MANIFEST_URL="https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml"
WORKDIR="/tmp/flannel-install"
MANIFEST_FILE="$WORKDIR/kube-flannel.yml"

# ───────────────────────── Header ───────────────────────────────────────────
info "infra-bootstrap — Flannel CNI Installation"
blank

# ───────────────────────── Phase 1: Cluster check ───────────────────────────
info "Verifying Kubernetes cluster access..."

ensure_kubeconfig

if ! kubectl get ns kube-system &>/dev/null; then
  error "Kubernetes cluster not accessible"
fi

ok "Cluster access verified"
blank

# ───────────────────────── Phase 2: Pod CIDR detection ──────────────────────
info "Detecting Pod CIDR from cluster..."

POD_CIDR=$(kubectl -n kube-system get cm kubeadm-config \
  -o jsonpath='{.data.ClusterConfiguration}' | \
  grep -E 'podSubnet:' | awk '{print $2}' || true)

if [[ -z "$POD_CIDR" ]]; then
  error "Unable to detect Pod CIDR from kubeadm-config"
fi

info "Detected Pod CIDR: $POD_CIDR"
info "This CIDR will be used for Flannel configuration"
blank

# ───────────────────────── Phase 3: Prepare workspace ───────────────────────
info "Preparing workspace..."
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
ok "Workspace ready: $WORKDIR"
blank

# ───────────────────────── Phase 4: Download Flannel manifest ───────────────
info "Downloading Flannel manifest (latest release)..."

curl -fsSL "$FLANNEL_MANIFEST_URL" -o "$MANIFEST_FILE"

ok "Flannel manifest downloaded"
blank

# ───────────────────────── Phase 5: Patch Pod CIDR ──────────────────────────
info "Patching Flannel network configuration..."

# Replace Network CIDR in ConfigMap
sed -i "s|\"Network\": \".*\"|\"Network\": \"${POD_CIDR}\"|" "$MANIFEST_FILE"

ok "Flannel manifest patched with cluster Pod CIDR"
blank

# ───────────────────────── Phase 6: Apply Flannel ───────────────────────────
info "Applying Flannel manifest..."
blank

kubectl apply -f "$MANIFEST_FILE"
blank

ok "Flannel manifest applied"
blank

# ───────────────────────── Phase 7: Stabilization wait ──────────────────────
info "Flannel Stabilization"

info "Waiting for kube-flannel namespace to be created..."
blank

for i in {1..60}; do
  kubectl get ns kube-flannel &>/dev/null && break
  sleep 2
done

kubectl get ns kube-flannel &>/dev/null || \
  error "kube-flannel namespace was not created"
blank

info "Waiting for Flannel components to become ready (this may take several minutes)..."
blank

info "Waiting for Flannel daemonset to become ready..."

SECONDS_WAITED=0
TIMEOUT=300
INTERVAL=15

while true; do
  if kubectl -n kube-flannel rollout status daemonset/kube-flannel-ds \
      --timeout=5s &>/dev/null; then
    ok "Flannel daemonset is ready"
    break
  fi

  sleep "$INTERVAL"
  SECONDS_WAITED=$((SECONDS_WAITED + INTERVAL))
  info "Still waiting for Flannel daemonset... (${SECONDS_WAITED}s elapsed)"

  if [[ $SECONDS_WAITED -ge $TIMEOUT ]]; then
    error "Flannel daemonset did not become ready within ${TIMEOUT}s"
  fi
done
blank

# ───────────────────────── Phase 8: Verification ────────────────────────────
info "Flannel Verification"

info "Verifying Flannel pods..."
blank

kubectl -n kube-flannel get pods -l app=flannel &>/dev/null || \
  error "Flannel pods not found after installation"
blank

ok "Flannel CNI installed and ready"
info "Flannel CNI installation completed successfully"
blank

exit 0
