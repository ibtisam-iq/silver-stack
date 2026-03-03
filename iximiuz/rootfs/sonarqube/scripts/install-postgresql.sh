#!/bin/bash
set -euo pipefail

#######################################################################
# PostgreSQL 18 Installation
#
# Installs PostgreSQL 18 via official PGDG apt repository.
# Runtime DB init (role + database) is done in lab-init.sh.
#
# Author: Muhammad Ibtisam Iqbal
#######################################################################

PG_VERSION=18

echo "Adding PostgreSQL PGDG apt repository..."

# Install helper and add PGDG repo via official script
apt-get update
apt-get install -y --no-install-recommends postgresql-common

# PGDG automated repo setup script (non-interactive)
yes '' | /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh || true

# Install PostgreSQL 18
apt-get update
apt-get install -y --no-install-recommends \
    postgresql-${PG_VERSION} \
    postgresql-contrib-${PG_VERSION}

# Enable PostgreSQL service; systemd will manage it at runtime
systemctl enable postgresql || true

apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

echo ""
echo "✓ PostgreSQL ${PG_VERSION} installed and enabled via PGDG"
echo "  DB/user will be created at container boot via lab-init.sh"
