#!/usr/bin/env bash
# ============================================================================
# infra-bootstrap — Kubernetes kubeconfig Setup
# Configures ~/.kube/config for kubectl access
# ============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

# ───────────────────────── Parse ALLOW ROOT flag ─────────────────────────────
ALLOW_ROOT=false

for arg in "$@"; do
  case "$arg" in
    --allow-root)
      ALLOW_ROOT=true
      ;;
  esac
done

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

info "Phase 10 — Configuring kubeconfig for administrator access"
blank

# ───────────────────────── Determine real user ──────────────────────────────
REAL_USER=""
REAL_HOME=""

if [[ "$EUID" -eq 0 ]]; then
  # Running via sudo
  if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    REAL_USER="$SUDO_USER"
    REAL_HOME="$(eval echo "~$SUDO_USER")"

    warn "Script is running with sudo."
    warn "kubeconfig will be configured for user: $REAL_USER"
    blank

    if ! confirm_or_abort "Type YES to configure kubeconfig for user '${REAL_USER}'"; then
      warn "User declined. Exiting without changes."
      exit 0
    fi

  else
    warn "Running as root without a real user context."
    warn "By default, this is considered unsafe."
    blank

    if [[ "$ALLOW_ROOT" != true ]]; then
      info "If you intentionally want to configure kubeconfig for the root user,"
      info "you can explicitly allow this behavior by appending the '--allow-root' flag."
      info "This flag tells the script to configure kubeconfig for the root user context."
      blank
      cmd "curl -fsSL $K8S_BASE_URL/cluster/kubeconfig-helper.sh | bash -s -- --allow-root"
      blank
      warn "Aborting without making any changes."
      blank
      exit 0
    fi

    warn "Proceeding with root kubeconfig configuration (explicitly allowed)."
    REAL_USER="root"
    REAL_HOME="/root"
  fi

else
  # Running as normal user
  REAL_USER="$(whoami)"
  REAL_HOME="$HOME"
  ok "Running as user: $REAL_USER"
fi

# ───────────────────────── Preconditions ────────────────────────────────────
if [[ ! -f /etc/kubernetes/admin.conf ]]; then
  error "/etc/kubernetes/admin.conf not found. Control plane may not be initialized."
fi

# ───────────────────────── Configure kubeconfig ─────────────────────────────
blank
info "Configuring kubeconfig for user: $REAL_USER"
blank

KUBE_DIR="$REAL_HOME/.kube"
KUBE_CONFIG="$KUBE_DIR/config"

# Create .kube directory (user-owned)
mkdir -p "$KUBE_DIR"

# Copy admin.conf with privilege
sudo cp -f /etc/kubernetes/admin.conf "$KUBE_CONFIG"

# Fix ownership and permissions
sudo chown "$REAL_USER:$REAL_USER" "$KUBE_CONFIG"
chmod 600 "$KUBE_CONFIG"

ok "kubeconfig written to $KUBE_CONFIG"
blank

# ───────────────────────── Verify kubectl access ────────────────────────────
info "Verifying kubectl access (this may take up to 60 seconds)..."

export KUBECONFIG="$KUBE_CONFIG"

sleep 10
if kubectl cluster-info >/dev/null 2>&1; then
  ok "kubectl access verified successfully"
  blank
else
  warn "kubectl could not reach the cluster yet"
  warn "The control plane may still be initializing"
  blank
fi

# ───────────────────────── CNI guidance ─────────────────────────────────────
CNI_CONFIG_COUNT=$(sudo sh -c 'ls -1 /etc/cni/net.d/*.conf /etc/cni/net.d/*.conflist 2>/dev/null | wc -l')

if [[ "$CNI_CONFIG_COUNT" -eq 0 ]]; then

#if ! compgen -G "/etc/cni/net.d/*.conf" > /dev/null && \
#   ! compgen -G "/etc/cni/net.d/*.conflist" > /dev/null; then
  warn "No CNI plugin configuration detected."
  info "A CNI plugin is required before pods can be scheduled."
  blank
  info "To install a CNI using infra-bootstrap, please run:"
  cmd "curl -fsSL $INSTALL_CNI_URL | sudo bash"
else
  ok "CNI plugin configuration detected."
  blank
fi

footer "kubeconfig setup completed successfully"

exit 0
