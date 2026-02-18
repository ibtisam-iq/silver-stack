#!/bin/bash

set -e

echo "=============================="
echo " Installing Gateway API CRDs "
echo "=============================="
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v1.5.1" | kubectl apply -f -

echo
echo "==========================================="
echo " Installing NGINX Gateway Fabric CRDs "
echo "==========================================="
kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v1.6.1/deploy/crds.yaml

echo
echo "=============================================="
echo " Installing NGINX Gateway Fabric (NodePort) "
echo "=============================================="
kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v1.6.1/deploy/nodeport/deploy.yaml

echo
echo "==============================================="
echo " Installing NGINX Ingress Controller (optional)"
echo "==============================================="
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.13.0/deploy/static/provider/cloud/deploy.yaml

echo
echo "===================================================="
echo " Installing Traefik via Helm (NodePort 32080 / 32443)"
echo "===================================================="

# Install Helm plugins/repo
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
chmod 700 get_helm.sh && ./get_helm.sh && rm -rf get_helm.sh
helm repo add traefik https://traefik.github.io/charts
helm repo update

# Install Traefik
helm upgrade --install traefik traefik/traefik \
  --namespace traefik \
  --set ports.web.nodePort=32080 \
  --set ports.websecure.nodePort=32443 \
  --set service.type=NodePort \
  --create-namespace \
  --skip-crds

echo
echo "==============================================="
echo " ✔ All components installed successfully! "
echo "==============================================="
