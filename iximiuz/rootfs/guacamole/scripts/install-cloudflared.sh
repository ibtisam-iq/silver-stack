#!/bin/bash
set -euo pipefail
#######################################################################
# install-cloudflared.sh
# Installs cloudflared (Cloudflare Tunnel CLI) from the official
# Cloudflare apt repository. Enables users to expose Guacamole
# publicly via Cloudflare Tunnel with automatic SSL — no firewall
# rules or port forwarding needed.
# Author: Muhammad Ibtisam Iqbal
#######################################################################

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

log "==> Installing cloudflared from official Cloudflare apt repo..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
    | tee /etc/apt/keyrings/cloudflare-main.gpg > /dev/null

echo "deb [signed-by=/etc/apt/keyrings/cloudflare-main.gpg] \
https://pkg.cloudflare.com/cloudflared any main" \
    | tee /etc/apt/sources.list.d/cloudflared.list > /dev/null

apt-get update -y
apt-get install -y cloudflared

log "✓ cloudflared $(cloudflared --version 2>&1 | head -1) installed"
