#!/bin/bash
set -euo pipefail
#######################################################################
# configure-guacamole.sh
# Writes guacamole.properties using build-time ARGs.
# DB password is intentionally NOT baked in here — lab-init.sh
# injects it at runtime from env or generates a random one.
# Arguments:
#   $1 - DB_NAME   (e.g. guacamole_db)
#   $2 - DB_USER   (e.g. guacamole_user)
#   $3 - GUAC_PORT (e.g. 8080)
# Author: Muhammad Ibtisam Iqbal
#######################################################################

DB_NAME="${1:?DB_NAME required}"
DB_USER="${2:?DB_USER required}"
GUAC_PORT="${3:-8080}"

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

log "==> Writing guacamole.properties..."
mkdir -p /etc/guacamole

cat > /etc/guacamole/guacamole.properties << EOF
guacd-hostname: localhost
guacd-port:     4822

mysql-hostname:           localhost
mysql-port:               3306
mysql-database:           ${DB_NAME}
mysql-username:           ${DB_USER}
mysql-password:           __DB_PASS__
mysql-auto-create-accounts: false
EOF

# Permissions: only tomcat can read it
chmod 600 /etc/guacamole/guacamole.properties
chown root:root /etc/guacamole/guacamole.properties
log "✓ guacamole.properties written (DB password placeholder set)"

log "==> Linking GUACAMOLE_HOME for Tomcat 10..."
ln -sf /etc/guacamole /var/lib/tomcat10/.guacamole
log "✓ /var/lib/tomcat10/.guacamole → /etc/guacamole"
