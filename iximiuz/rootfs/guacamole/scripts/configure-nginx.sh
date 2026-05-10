#!/bin/bash
set -euo pipefail
#######################################################################
# configure-nginx.sh
# Installs nginx (if not already present), enables the guacamole
# site (already deployed from configs/nginx/guacamole.conf via COPY),
# removes the default site, and validates config.
# Author: Muhammad Ibtisam Iqbal
#######################################################################

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

log "==> Installing nginx..."
apt-get install -y nginx
log "✓ nginx installed"

log "==> Enabling Guacamole nginx site..."
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/guacamole /etc/nginx/sites-enabled/guacamole
log "✓ guacamole site enabled, default site removed"

log "==> Validating nginx configuration..."
nginx -t
log "✓ nginx config valid"
