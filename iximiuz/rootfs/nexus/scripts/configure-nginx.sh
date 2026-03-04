#!/bin/bash
set -euo pipefail

#######################################################################
# configure-nginx.sh
#
# Configures Nginx as a reverse proxy for Nexus Repository Manager.
#
# Author: Muhammad Ibtisam Iqbal
#######################################################################

echo "Installing Nginx..."
apt-get update
apt-get install -y --no-install-recommends nginx

echo "Configuring Nginx for Nexus..."

if [ ! -f /etc/nginx/sites-available/nexus ]; then
    echo "ERROR: Nginx configuration not found: /etc/nginx/sites-available/nexus"
    exit 1
fi

echo "Removing default Nginx site..."
rm -f /etc/nginx/sites-enabled/default
echo "✓ Default site removed"

echo "Enabling Nexus site..."
ln -sf /etc/nginx/sites-available/nexus /etc/nginx/sites-enabled/nexus
echo "✓ Nexus site enabled"

# Override stock nginx.service to run in foreground for systemd container compatibility
echo "Creating Nginx systemd override..."
mkdir -p /etc/systemd/system/nginx.service.d
cat > /etc/systemd/system/nginx.service.d/override.conf << 'EOF'
[Service]
Type=simple
KillSignal=SIGQUIT
TimeoutStopSec=5
ExecStartPre=
ExecStartPre=/usr/sbin/nginx -t
ExecStart=
ExecStart=/usr/sbin/nginx -g 'daemon off;'
ExecReload=
ExecReload=/usr/sbin/nginx -s reload
EOF
echo "✓ Nginx systemd override created"

echo "Testing Nginx configuration..."
nginx -t

echo ""
echo "✓ Nginx configured successfully"
echo "  Config  : /etc/nginx/sites-available/nexus"
echo "  Enabled : /etc/nginx/sites-enabled/nexus"
echo "  Logs    : /var/log/nginx/nexus-*.log"
