#!/bin/bash
set -euo pipefail

#######################################################################
# install-cloudflared.sh
#
# Installs cloudflared from the official Cloudflare apt repository.
#
# Author: Muhammad Ibtisam Iqbal
#######################################################################

echo "Installing cloudflared..."

echo "Adding Cloudflare GPG key..."
curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg | \
    tee /usr/share/keyrings/cloudflare-public-v2.gpg > /dev/null

echo "Adding Cloudflare apt repository..."
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main' | \
    tee /etc/apt/sources.list.d/cloudflared.list

echo "Updating package index..."
apt-get update -y

echo "Installing cloudflared package..."
apt-get install -y --no-install-recommends cloudflared

echo "Verifying installation..."
cloudflared --version

echo "Cleaning up apt cache and temporary files..."
apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    apt-get autoremove -y

echo ""
echo "✓ cloudflared installed successfully"
echo "  Binary  : $(which cloudflared)"
echo "  Version : $(cloudflared --version)"
