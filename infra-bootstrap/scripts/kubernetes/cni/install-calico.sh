#!/usr/bin/env bash
# ============================================================================
# infra-bootstrap — Install Calico CNI
# ----------------------------------------------------------------------------
# Installs Calico using Tigera Operator and cluster-derived Pod CIDR.
#
# Characteristics:
#   - curl | bash safe
#   - No environment variable dependency
#   - Pod CIDR is detected from cluster (source of truth)
#   - Real-time Calico version with safe fallback
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

# ───────────────────────── Defaults ─────────────────────────────────────────
DEFAULT_CALICO_VERSION="v3.31.2"
ENCAPSULATION_MODE="VXLAN"

WORKDIR="/tmp/calico-install"
CUSTOM_RESOURCES_FILE="$WORKDIR/custom-resources.yaml"

# ───────────────────────── Header ───────────────────────────────────────────
info "infra-bootstrap — Calico CNI Installation"
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
blank

# ───────────────────────── Phase 3: Existing Calico check ──────────────────
info "Checking for existing Calico installation..."

CALICO_PRESENT=false
MAX_WAIT_SECONDS=60   
SLEEP_INTERVAL=15

if kubectl get installation.operator.tigera.io default >/dev/null 2>&1; then
  CALICO_PRESENT=true
fi

if [[ "$CALICO_PRESENT" == true ]]; then
  warn "Existing Calico Installation detected (default)."
  blank
  kubectl get installation.operator.tigera.io default
  blank

  info "This may take up to ${MAX_WAIT_SECONDS}s."
  info "If automatic cleanup does not complete, manual recovery steps will be provided."
  blank

  info "Waiting for existing Calico Installation (default) to be fully removed..."
  blank

  elapsed=0

  while kubectl get installation.operator.tigera.io default >/dev/null 2>&1; do
    if (( elapsed >= MAX_WAIT_SECONDS )); then
      warn "Timed out waiting for Installation/default to be deleted."
      blank

      warn "Proceeding further is unsafe while an existing Installation is present."
      warn "Manual cleanup is required before retrying."
      blank

      info "Recommended manual cleanup steps:"
      info "Run the following commands in the order shown:"
      blank

      cmd "kubectl scale deployment tigera-operator -n tigera-operator --replicas=0"
      cmd "kubectl patch installation.operator.tigera.io default --type=json -p='[{\"op\":\"remove\",\"path\":\"/metadata/finalizers\"}]'"
      cmd "kubectl delete installation.operator.tigera.io default --grace-period=0 --force"
      cmd "kubectl delete deployment tigera-operator -n tigera-operator --force"
      blank

      info "After cleanup completes, re-run this script:"
      cmd "curl -fsSL $INSTALL_CALICO_URL | bash"
      blank

      exit 1
    fi

    remaining=$(( MAX_WAIT_SECONDS - elapsed ))
    info "Installation/default still present — waited ${elapsed}s, remaining ${remaining}s (manual steps will be shown on timeout)"
    blank

    sleep "$SLEEP_INTERVAL"
    elapsed=$(( elapsed + SLEEP_INTERVAL ))
  done

  ok "Existing Calico Installation successfully removed"
  blank

else
  ok "No existing Calico Installation detected"
  blank
fi

# ───────────────────────── Phase 4: Encapsulation config ──────────────────────
info "Calico encapsulation mode configuration"
info "Default encapsulation mode: VXLAN (industry standard)"
info "Press Enter to keep default, or specify a different value (e.g. IPIP)"
blank
read -rp "Encapsulation mode [VXLAN]: " USER_ENCAPSULATION </dev/tty || true

if [[ -n "$USER_ENCAPSULATION" ]]; then
  ENCAPSULATION_MODE="$USER_ENCAPSULATION"
fi

blank
info "Using encapsulation mode: $ENCAPSULATION_MODE"
blank

# ───────────────────────── Phase 5: Calico version resolution ───────────────
info "Resolving Calico version..."

CALICO_VERSION=""

if command -v curl &>/dev/null; then
  CALICO_VERSION=$(curl -fsSL https://api.github.com/repos/projectcalico/calico/releases/latest \
    | grep '"tag_name"' | cut -d '"' -f4 || true)
fi

if [[ -z "$CALICO_VERSION" ]]; then
  warn "Unable to fetch Calico version in real-time"
  CALICO_VERSION="$DEFAULT_CALICO_VERSION"
  info "Falling back to default Calico version: $CALICO_VERSION"
else
  ok "Resolved Calico version: $CALICO_VERSION"
fi

blank

# ───────────────────────── Phase 6: Prepare workspace ───────────────────────
info "Preparing workspace..."
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
ok "Workspace ready: $WORKDIR"
blank

# ───────────────────────── Phase 7: Install Tigera Operator ─────────────────
info "Installing Tigera Operator..."
kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/operator-crds.yaml" 
blank
kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml"
blank
ok "Tigera Operator applied"
blank

# ───────────────────────── Phase 8: Download custom resources ───────────────
info "Downloading Calico custom resources..."

curl -fsSL \
  "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/custom-resources.yaml" \
  -o "$CUSTOM_RESOURCES_FILE"

ok "Custom resources downloaded"
blank

# ───────────────────────── Phase 9: Patch custom resources ──────────────────
info "Patching custom resources with cluster CIDR..."

# Update Pod CIDR
sed -i "s|cidr: .*|cidr: ${POD_CIDR}|" "$CUSTOM_RESOURCES_FILE"

# Ensure VXLAN encapsulation
sed -i "s|encapsulation: .*|encapsulation: ${ENCAPSULATION_MODE}|" "$CUSTOM_RESOURCES_FILE"

ok "Custom resources patched"
blank


# ───────────────────────── Phase 10: Apply custom resources ──────────────────
info "Applying Calico custom resources..."
blank

kubectl create -f "$CUSTOM_RESOURCES_FILE"
blank

ok "Calico custom resources applied"
blank

# ───────────────────────── Phase 11: Stabilization wait ──────────────────────
info "Waiting for calico-system namespace to be created..."

for i in {1..60}; do
  kubectl get ns calico-system &>/dev/null && break
  sleep 2
done

kubectl get ns calico-system &>/dev/null || \
  error "calico-system namespace was not created"
blank

info "Waiting for Calico components to become ready (this may take several minutes)..."
blank

kubectl -n calico-system rollout status deployment/calico-kube-controllers \
  --timeout=300s || error "Calico controllers failed to become ready"
blank

kubectl -n calico-system rollout status daemonset/calico-node \
  --timeout=300s || error "Calico node daemonset not ready"
blank

# ───────────────────────── Phase 12: Verification ───────────────────────────
info "Verifying Calico pods..."
blank

kubectl -n calico-system get pods &>/dev/null || \
  error "Calico pods not found after installation"
blank

ok "Calico CNI installed and ready"
info "Calico CNI installation completed successfully"
blank
exit 0
