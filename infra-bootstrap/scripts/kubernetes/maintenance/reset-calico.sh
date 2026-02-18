#!/bin/bash

echo "[INFO] Starting Calico reset procedure..."
exit 0

# 1. Scale operator to 0 (stop immediate reconciliation)
kubectl scale deployment tigera-operator -n tigera-operator --replicas=0 --timeout=5m

echo "[INFO] Removing finalizers from any remaining resources in calico-system..."

# For any remaining pods
for pod in $(kubectl get pods -n calico-system -o name); do
    kubectl patch $pod -n calico-system --type=json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' || true
done

# For DaemonSets
for ds in $(kubectl get daemonset -n calico-system -o name); do
    kubectl patch $ds -n calico-system --type=json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' || true
done

# For Deployments
for deploy in $(kubectl get deployment -n calico-system -o name); do
    kubectl patch $deploy -n calico-system --type=json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' || true
done

# Final force cleanup
kubectl -n calico-system delete pods,daemonset,deployment --all --force --grace-period=0 || true



# 3. Delete the Installation CR (with finalizer removal)
kubectl patch installation.operator.tigera.io default --type=json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' || true
kubectl delete installation.operator.tigera.io default --force --grace-period=0 || true

# 4. Delete the operator deployment itself
kubectl delete deployment tigera-operator -n tigera-operator --force --grace-period=0

# 4. Delete the operator deployment itself
if kubectl get deployment tigera-operator -n tigera-operator; then
  echo "Deleting deployment tigera-operator..."
  kubectl delete deployment tigera-operator -n tigera-operator --force --grace-period=0
fi

# 5. RoleBinding (depends on ServiceAccount and ClusterRole)
if kubectl get rolebinding tigera-operator-secrets -n tigera-operator; then
  echo "Deleting rolebinding tigera-operator-secrets..."
  kubectl delete rolebinding tigera-operator-secrets -n tigera-operator
fi

# 6. ClusterRoleBinding (depends on ServiceAccount and ClusterRole)
if kubectl get clusterrolebinding tigera-operator; then
  echo "Deleting clusterrolebinding tigera-operator..."
  kubectl delete clusterrolebinding tigera-operator
fi

# 7. ClusterRoles
for cr in tigera-operator tigera-operator-secrets; do
  if kubectl get clusterrole "$cr" >/dev/null 2>&1; then
    echo "Deleting clusterrole $cr..."
    kubectl delete clusterrole "$cr"
  fi
done

# 8. ServiceAccount
if kubectl get serviceaccount tigera-operator -n tigera-operator; then
  echo "Deleting serviceaccount tigera-operator..."
  kubectl delete serviceaccount tigera-operator -n tigera-operator
fi


# 1. Remove finalizers from the stuck serviceaccounts in calico-system
echo "Removing finalizers from remaining serviceaccounts in calico-system..."
kubectl get serviceaccount -n calico-system -o name | while read sa; do
    echo "  Patching $sa to remove finalizers..."
    kubectl patch $sa -n calico-system --type=json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' || true
done

# Force delete the serviceaccounts (just in case)
kubectl -n calico-system delete serviceaccount --all --force --grace-period=0 || true


# 7. (Optional but recommended) Remove Tigera CRDs — this fully prevents any future auto-reconciliation
kubectl delete crd installations.operator.tigera.io apiservers.operator.tigera.io tigerastatuses.operator.tigera.io --force --grace-period=0 || true

# Delete all Calico/Tigera-related CRDs
kubectl delete crd $(kubectl get crd | grep -E '(tigera|projectcalico)' | awk '{print $1}') --force --grace-period=0 || true
# If any specific ones remain (common ones)
kubectl delete crd adminnetworkpolicies.policy.networking.k8s.io baselineadminnetworkpolicies.policy.networking.k8s.io bgpconfigurations.crd.projectcalico.org bgppeers.crd.projectcalico.org blockaffinities.crd.projectcalico.org clusterinformations.crd.projectcalico.org felixconfigurations.crd.projectcalico.org globalnetworkpolicies.crd.projectcalico.org globalnetworksets.crd.projectcalico.org hostendpoints.crd.projectcalico.org ipamblocks.crd.projectcalico.org ipamconfigs.crd.projectcalico.org ipamhandles.crd.projectcalico.org ippools.crd.projectcalico.org kubecontrollersconfigurations.crd.projectcalico.org networkpolicies.crd.projectcalico.org networksets.crd.projectcalico.org installations.operator.tigera.io apiservers.operator.tigera.io tigerastatuses.operator.tigera.io --force --grace-period=0 || true


# 5. Delete the tigera-operator namespace (with finalizer removal if stuck)
#kubectl patch namespace tigera-operator -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
kubectl patch namespace tigera-operator --type=json -p '[{"op": "remove", "path": "/metadata/finalizers"}]' || true
kubectl delete namespace tigera-operator --force --grace-period=0

# 6. Delete the calico-system namespace (final cleanup)
#kubectl patch namespace calico-system -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
kubectl patch namespace calico-system --type=json -p '[{"op": "remove", "path": "/metadata/finalizers"}]' || true
kubectl delete namespace calico-system --force --grace-period=0



# === FULL CALICO NODE CLEANUP (run with sudo on EVERY node) ===

echo "Starting Calico node cleanup..."

# 1. Get Pod CIDR dynamically from the cluster (from Installation CR or node spec)
# Get the actual Calico Pod CIDR (primary source)
POD_CIDR=$(kubectl get installation default -o jsonpath='{.spec.calicoNetwork.ipPools[0].cidr}' 2>/dev/null || echo "")

# Fallback 1: kubeadm-config (Kubernetes cluster CIDR)
if [ -z "$POD_CIDR" ]; then
  echo "Installation CR not found. Falling back to kubeadm-config..."
  POD_CIDR=$(kubectl get configmap kubeadm-config -n kube-system -o jsonpath='{.data.ClusterConfiguration.podSubnet}' 2>/dev/null || echo "")
fi

# Fallback 2: Local node spec (rarely useful in single-node, but complete)
if [ -z "$POD_CIDR" ]; then
  echo "kubeadm-config not found. Falling back to local node podCIDR..."
  POD_CIDR=$(kubectl get node "$(hostname)" -o jsonpath='{.spec.podCIDR}' 2>/dev/null || echo "")
fi

if [ -z "$POD_CIDR" ]; then
  echo "Error: Could not determine Pod CIDR. Skipping blackhole route cleanup."
else
  echo "Using Pod CIDR for cleanup: $POD_CIDR"
  sudo ip route del blackhole "$POD_CIDR" proto 80 2>/dev/null || true
fi

# 2. Remove Calico CNI config files
sudo rm -f /etc/cni/net.d/10-calico.conflist /etc/cni/net.d/calico-kubeconfig

# 3. Delete Calico-specific interfaces
sudo ip link delete vxlan.calico 2>/dev/null || true
sudo ip link list | grep -o 'cali[^[:space:]]*' | xargs -r -I {} sudo ip link delete {} 2>/dev/null || true
sudo ip link delete tunl0 2>/dev/null || true


# 5. Delete CNI network namespaces
sudo ip netns list | grep -E 'cni-|cali-' | awk '{print $1}' | xargs -r -I {} sudo ip netns delete {} 2>/dev/null || true

# 6. Delete all veth pairs (pod-to-host links — safe during reset)
sudo ip link list type veth | awk -F: '{print $1}' | xargs -r -I {} sudo ip link delete {} 2>/dev/null || true

echo "[INFO] Cleaning up leftover Calico network interfaces on the host..."

# 5. Force delete all cali* interfaces (even if UP or attached)
sudo ip link list | grep -o 'cali[^[:space:]]*' | while read iface; do
    echo "  Deleting leftover interface $iface..."
    sudo ip link set "$iface" down 2>/dev/null || true
    sudo ip link delete "$iface" 2>/dev/null || true
done







# 6. Remove Calico blackhole and per-pod routes
if [ -n "$POD_CIDR" ]; then
  sudo ip route del blackhole "$POD_CIDR" proto 80 2>/dev/null || true
fi
sudo ip route list | grep "dev cali" | awk '{print $1}' | xargs -r -I {} sudo ip route del {} 2>/dev/null || true

# 7. Flush and delete all Calico iptables chains (filter, nat, mangle)
for table in filter nat mangle; do
  chains=$(sudo iptables -t "$table" -L 2>/dev/null | grep '^Chain cali-' | awk '{print $2}')
  for chain in $chains; do
    sudo iptables -t "$table" -F "$chain" 2>/dev/null || true
    sudo iptables -t "$table" -X "$chain" 2>/dev/null || true
  done
done

# 8. Restart kubelet to clear cached state
echo "Restarting kubelet..."
sudo systemctl restart kubelet



# 5. Final verification
echo "Verification:"
kubectl get ns | grep -E '(calico-system|tigera-operator)' || echo "Both namespaces gone"
kubectl get crd | grep -E '(tigera|projectcalico)' || echo "All Tigera/Calico CRDs removed"
kubectl get installation.operator.tigera.io 2>/dev/null || echo "No Installation resource left"