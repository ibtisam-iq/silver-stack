#!/usr/bin/env bash
# =============================================================================
# remove-flannel.sh
#
# Purpose:
#   Safely detect and remove Flannel CNI from a Kubernetes node/cluster.
#
# Characteristics:
#   - Idempotent
#   - Detection-first
#   - Kubernetes + OS-level cleanup
#   - Production-safe logging
#
# Usage:
#   sudo bash remove-flannel.sh
#
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

echo "infra-bootstrap — Flannel CNI Removal"
exit 0

# ───────────────────────── Logging helpers ────────────────────────────────
info() { echo -e "[INFO]    $*"; }
ok()   { echo -e "[ OK ]    $*"; }
warn() { echo -e "[WARN]    $*"; }
die()  { echo -e "[FAIL]    $*" >&2; exit 1; }

trap 'die "Error at line $LINENO"' ERR

# ───────────────────────── Preflight checks ───────────────────────────────
command -v kubectl >/dev/null || die "kubectl not found"
command -v ip >/dev/null || die "iproute2 not found"

if [[ $EUID -ne 0 ]]; then
  die "Run as root (sudo)"
fi

info "Starting Flannel removal procedure"

# ───────────────────────── Detect Flannel ────────────────────────────────
FLANNEL_NS_EXISTS=false
kubectl get ns kube-flannel >/dev/null 2>&1 && FLANNEL_NS_EXISTS=true

FLANNEL_IF_EXISTS=false
ip link show flannel.1 >/dev/null 2>&1 && FLANNEL_IF_EXISTS=true

if ! $FLANNEL_NS_EXISTS && ! $FLANNEL_IF_EXISTS; then
  ok "Flannel not detected — nothing to remove"
  exit 0
fi

ok "Flannel detected"

# ───────────────────────── Kubernetes cleanup ─────────────────────────────
if $FLANNEL_NS_EXISTS; then
  info "Deleting Flannel Kubernetes resources"

  kubectl delete ns kube-flannel \
    --ignore-not-found \
    --wait=true

  ok "Flannel namespace removed"
else
  ok "Flannel namespace not present"
fi

# Remove flannel annotations from nodes (safe + optional)
info "Removing Flannel annotations from nodes"
kubectl get nodes -o name | while read -r node; do
  kubectl annotate "$node" \
    flannel.alpha.coreos.com/backend-data- \
    flannel.alpha.coreos.com/backend-type- \
    flannel.alpha.coreos.com/public-ip- \
    --overwrite >/dev/null 2>&1 || true
done
ok "Node annotations cleaned"

# ───────────────────────── Stop kubelet briefly ───────────────────────────
info "Stopping kubelet temporarily"
systemctl stop kubelet

# ───────────────────────── CNI config cleanup ─────────────────────────────
info "Removing Flannel CNI configuration"
rm -f /etc/cni/net.d/*flannel* || true
rm -f /etc/cni/net.d/10-flannel.conflist || true
ok "CNI config cleaned"

# ───────────────────────── Network interfaces ─────────────────────────────
info "Removing Flannel network interfaces"

for iface in flannel.1 cni0 tunl0; do
  if ip link show "$iface" >/dev/null 2>&1; then
    ip link delete "$iface" || true
    ok "Deleted interface: $iface"
  fi
done

# ───────────────────────── Routes cleanup ────────────────────────────────
info "Removing Flannel routes"

ip route | grep -E '10\.244\.' | while read -r route; do
  ip route del $route || true
done

ok "Routes cleaned"

# ───────────────────────── Network namespaces ─────────────────────────────
info "Removing CNI network namespaces"

ip netns list | awk '{print $1}' | grep '^cni-' | while read -r ns; do
  ip netns delete "$ns" || true
done

ok "Network namespaces removed"

# ───────────────────────── Filesystem cleanup ─────────────────────────────
info "Removing Flannel state directories"

rm -rf /var/lib/cni/flannel
rm -rf /var/lib/cni/networks/10.244.0.0*
rm -rf /run/flannel
rm -rf /etc/flannel

ok "Filesystem cleaned"

# ───────────────────────── Restart kubelet ────────────────────────────────
info "Starting kubelet"
systemctl start kubelet

ok "Flannel removal completed successfully"

# ───────────────────────── Post-check summary ─────────────────────────────
info "Post-removal verification hints:"
echo "  kubectl get pods -A"
echo "  ip link"
echo "  ip route"
echo "  ls /etc/cni/net.d"

exit 0