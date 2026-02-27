#!/bin/bash
set -euo pipefail

#######################################################################
# configure-nginx.sh
#
# Configures Nginx as a reverse proxy for Jenkins.
#
# Author: Muhammad Ibtisam Iqbal
#######################################################################

echo "Configuring Nginx for Jenkins..."

if [ ! -f /etc/nginx/sites-available/jenkins ]; then
    echo "ERROR: Nginx configuration not found: /etc/nginx/sites-available/jenkins"
    exit 1
fi

echo "Removing default Nginx site..."
rm -f /etc/nginx/sites-enabled/default
echo "✓ Default site removed"

echo "Enabling Jenkins site..."
ln -sf /etc/nginx/sites-available/jenkins /etc/nginx/sites-enabled/jenkins
echo "✓ Jenkins site enabled"

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
echo "  Config  : /etc/nginx/sites-available/jenkins"
echo "  Enabled : /etc/nginx/sites-enabled/jenkins"
echo "  Logs    : /var/log/nginx/jenkins-*.log"
