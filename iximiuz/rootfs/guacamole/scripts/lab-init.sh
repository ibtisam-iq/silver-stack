#!/bin/bash
set -euo pipefail
#######################################################################
# lab-init.sh
# Runs once per boot via systemd oneshot (lab-init.service)
# BEFORE mariadb, tomcat10, guacd, xrdp, nginx start.
#
# Responsibilities:
#   1. Generate SSH host keys (ephemeral per VM)
#   2. Create runtime directories (/run/sshd, /run/nginx, /run/xrdp)
#   3. Start MariaDB, create DB + user (idempotent)
#   4. Import Guacamole schema (idempotent via IF NOT EXISTS guard)
#   5. Pre-seed RDP connection into guacamole_connection table
#   6. Inject DB_PASS into guacamole.properties
#   7. Fix /run/xrdp ownership for xrdp tmpfiles
#
# Environment variables (all have safe defaults):
#   DB_NAME         - MariaDB database name       (default: guacamole_db)
#   DB_USER         - MariaDB user                (default: guacamole_user)
#   DB_PASS         - MariaDB password            (default: auto-generated)
#   RDP_USER        - XRDP desktop username       (default: musk)
#   RDP_PASS        - XRDP desktop password       (default: auto-generated)
#   RDP_PORT        - XRDP port                   (default: 3389)
#   GUAC_PORT       - Tomcat/Guacamole port       (default: 8080)
#
# Author: Muhammad Ibtisam Iqbal
#######################################################################

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

DB_NAME="${DB_NAME:-guacamole_db}"
DB_USER="${DB_USER:-guacamole_user}"
DB_PASS="${DB_PASS:-$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 20)}"
RDP_USER="${RDP_USER:-musk}"
RDP_PASS="${RDP_PASS:-$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 12)}"
RDP_PORT="${RDP_PORT:-3389}"
GUAC_PORT="${GUAC_PORT:-8080}"

log "Starting Guacamole lab runtime initialization..."
log "DB_NAME=${DB_NAME} | DB_USER=${DB_USER} | RDP_USER=${RDP_USER} | RDP_PORT=${RDP_PORT} | GUAC_PORT=${GUAC_PORT}"

# ── 1. SSH host keys ──────────────────────────────────────────────────────────
if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
    log "Generating SSH host keys..."
    ssh-keygen -A
    log "✓ SSH host keys generated"
else
    log "SSH host keys already exist"
fi
mkdir -p /run/sshd
chmod 755 /run/sshd

# ── 2. Runtime directories ───────────────────────────────────────────────────
mkdir -p /run/nginx
log "✓ /run/nginx created"

mkdir -p /run/xrdp
chown xrdp:xrdp /run/xrdp
chmod 755 /run/xrdp
log "✓ /run/xrdp created"

# ── 3. Start MariaDB (socket method, no root password needed) ────────────────
log "Starting MariaDB..."
mysqld_safe --no-defaults --skip-syslog &
MARIADB_PID=$!

log "Waiting for MariaDB to become ready..."
for i in {1..40}; do
    if mysqladmin ping --silent 2>/dev/null; then
        log "✓ MariaDB is ready"
        break
    fi
    log "Waiting... (${i}/40)"
    sleep 1
done

# ── 4. Create database and user (idempotent) ─────────────────────────────────
log "Ensuring database '${DB_NAME}' and user '${DB_USER}' exist..."
mysql --silent << EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT SELECT,INSERT,UPDATE,DELETE ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF
log "✓ Database and user ensured"

# ── 5. Import schema (idempotent — only if guacamole_connection table absent) ─
TABLE_EXISTS=$(mysql -sN -e "SELECT COUNT(*) FROM information_schema.tables \
    WHERE table_schema='${DB_NAME}' AND table_name='guacamole_connection';" 2>/dev/null || echo "0")

if [ "${TABLE_EXISTS}" = "0" ]; then
    log "Importing Guacamole schema..."
    for sql_file in /opt/guacamole-schema/*.sql; do
        log "  Importing ${sql_file}..."
        mysql "${DB_NAME}" < "${sql_file}"
    done
    log "✓ Schema imported"
else
    log "Schema already imported — skipping"
fi

# ── 6. Pre-seed RDP connection (idempotent) ───────────────────────────────────
CONN_EXISTS=$(mysql -sN "${DB_NAME}" -e \
    "SELECT COUNT(*) FROM guacamole_connection WHERE connection_name='XFCE Desktop RDP';" \
    2>/dev/null || echo "0")

if [ "${CONN_EXISTS}" = "0" ]; then
    log "Pre-seeding RDP connection (${RDP_USER}@127.0.0.1:${RDP_PORT})..."
    mysql "${DB_NAME}" << EOF
INSERT INTO guacamole_connection
    (connection_name, protocol, max_connections, max_connections_per_user)
VALUES
    ('XFCE Desktop RDP', 'rdp', 1, 1);

SET @conn_id = LAST_INSERT_ID();

INSERT INTO guacamole_connection_parameter
    (connection_id, parameter_name, parameter_value)
VALUES
    (@conn_id, 'hostname',     '127.0.0.1'),
    (@conn_id, 'port',         '${RDP_PORT}'),
    (@conn_id, 'username',     '${RDP_USER}'),
    (@conn_id, 'password',     '${RDP_PASS}'),
    (@conn_id, 'security',     'rdp'),
    (@conn_id, 'ignore-cert',  'true'),
    (@conn_id, 'color-depth',  '32'),
    (@conn_id, 'disable-audio','false'),
    (@conn_id, 'audio-servername','rdpsnd');

INSERT INTO guacamole_connection_permission (entity_id, connection_id, permission)
SELECT entity_id, @conn_id, 'READ'
FROM guacamole_entity WHERE name = 'guacadmin' AND type = 'USER';

INSERT INTO guacamole_connection_permission (entity_id, connection_id, permission)
SELECT entity_id, @conn_id, 'UPDATE'
FROM guacamole_entity WHERE name = 'guacadmin' AND type = 'USER';

INSERT INTO guacamole_connection_permission (entity_id, connection_id, permission)
SELECT entity_id, @conn_id, 'DELETE'
FROM guacamole_entity WHERE name = 'guacadmin' AND type = 'USER';

INSERT INTO guacamole_connection_permission (entity_id, connection_id, permission)
SELECT entity_id, @conn_id, 'ADMINISTER'
FROM guacamole_entity WHERE name = 'guacadmin' AND type = 'USER';
EOF
    log "✓ RDP connection pre-seeded"
else
    log "RDP connection already exists — skipping"
fi

# ── 7. Set RDP user password (idempotent — always sync at boot) ───────────────
log "Setting password for RDP user '${RDP_USER}'..."
echo "${RDP_USER}:${RDP_PASS}" | chpasswd
log "✓ RDP user password set"

# ── 8. Inject DB_PASS into guacamole.properties ───────────────────────────────
log "Injecting DB_PASS into guacamole.properties..."
sed -i "s/__DB_PASS__/${DB_PASS}/" /etc/guacamole/guacamole.properties
chown tomcat:tomcat /etc/guacamole/guacamole.properties
log "✓ guacamole.properties updated"

# ── 9. Stop the temporary MariaDB (systemd will restart it properly) ──────────
log "Stopping temporary MariaDB (systemd will manage it from here)..."
kill "${MARIADB_PID}" 2>/dev/null || true
sleep 2
log "✓ Temporary MariaDB stopped"

# ── Print credentials for lab users ──────────────────────────────────────────
log "============================================================"
log " CREDENTIALS SUMMARY"
log "  Guacamole URL:  http://localhost:${GUAC_PORT}/guacamole"
log "  Guacamole login: guacadmin / guacadmin"
log "  RDP user:        ${RDP_USER} / ${RDP_PASS}"
log "  DB user:         ${DB_USER} / ${DB_PASS}"
log "============================================================"
log "✓ Initialization complete — systemd will now start all services"
