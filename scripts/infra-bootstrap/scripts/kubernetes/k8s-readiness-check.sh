#!/bin/bash

set -euo pipefail
trap 'echo -e "\n\033[1;31m❌ Error at line $LINENO. Exiting...\033[0m"; exit 1' ERR

# Debug mode (set DEBUG=true to enable)
DEBUG=${DEBUG:-false}
if [ "$DEBUG" == "true" ]; then
    set -x
fi

# Logging setup
# LOG_FILE="/var/log/k8s-readiness-check.log"
# echo "$(date) - Starting Kubernetes Control Plane Setup" # >> "$LOG_FILE"

# Check Kubernetes API server readiness
timeout=90
elapsed=0
echo "⏳ Waiting for Kubernetes API server to be ready..."
while ! ss -tulnp | grep -E "6443" &>/dev/null; do # sudo netstat is deprecated
    if [[ $elapsed -ge $timeout ]]; then
        echo "❌ Kubernetes API server did not start within $timeout seconds. Exiting..."
        exit 1
    fi
    echo "⏳ Still waiting... ($elapsed s elapsed)"
    sleep 5
    ((elapsed+=5))
done
echo -e "\033[1;32m✅ Kubernetes API server is running.\033[0m" # | tee -a "$LOG_FILE"

# Waiting for Cluster Readiness (10 min max)
echo -e "\n\033[1;33m⏳ Waiting up to 10 minutes for the control plane and pods to become ready...\033[0m"
TIMEOUT=600  # 10 minutes in seconds
INTERVAL=30  # Check every 30 seconds
elapsed=0

while [[ $elapsed -lt $TIMEOUT ]]; do
    NODES_READY=$(kubectl get nodes -o=jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' | grep -c True)
#   NODES_READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -c ' Ready ')
    PODS_READY=$(kubectl get pods -A --no-headers 2>/dev/null | awk '{print $4}' | grep -c 'Running')

    echo -e "\n\033[1;33m📊 Status: Nodes Ready: $NODES_READY | Pods Running: $PODS_READY (Elapsed: $elapsed sec)\033[0m"

    if [[ $NODES_READY -gt 0 && $PODS_READY -gt 0 ]]; then
        echo -e "\033[1;32m✅ Control plane and all pods are ready.\033[0m"
        break
    fi

    sleep $INTERVAL
    ((elapsed+=INTERVAL))
done

if [[ $elapsed -ge $TIMEOUT ]]; then
    echo -e "\n\033[1;31m❌ Timeout! Cluster not ready after 10 minutes. Exiting...\033[0m"
    exit 1
fi

echo -e "\n\033[1;32m🎉 k8s-readiness-check.sh script is completed!\033[0m"