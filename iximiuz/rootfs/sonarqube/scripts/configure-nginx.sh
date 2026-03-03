#!/bin/bash
set -euo pipefail

#######################################################################
# configure-nginx.sh
#
# Configures Nginx as a reverse proxy for SonarQube.
#
# Author: Muhammad Ibtisam Iqbal
#######################################################################

echo "Configuring Nginx for SonarQube..."

if [ ! -f /etc/nginx/sites-available/sonarqube ]; then
    echo "ERROR: Nginx configuration not found: /etc/nginx/sites-available/sonarqube"
    exit 1
fi

echo "Removing default Nginx site..."
rm -f /etc/nginx/sites-enabled/default
echo "✓ Default site removed"

echo "Enabling SonarQube site..."
ln -sf /etc/nginx/sites-available/sonarqube /etc/nginx/sites-enabled/sonarqube
echo "✓ SonarQube site enabled"

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
echo "  Config  : /etc/nginx/sites-available/sonarqube"
echo "  Enabled : /etc/nginx/sites-enabled/sonarqube"
echo "  Logs    : /var/log/nginx/sonarqube-*.log"
