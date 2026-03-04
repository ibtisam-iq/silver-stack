#!/bin/bash
set -euo pipefail

#######################################################################
# SonarQube Lab Runtime Initialization
#
# Runs once per boot via systemd oneshot service (lab-init.service)
#
# Author: Muhammad Ibtisam Iqbal
#######################################################################

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

log "Starting SonarQube lab runtime initialization..."

# ──────────────────────────────────────────────────────────────────────
# SSH
# ──────────────────────────────────────────────────────────────────────
if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
    log "Generating SSH host keys..."
    ssh-keygen -A
    log "✓ SSH host keys generated"
else
    log "SSH host keys already exist"
fi

mkdir -p /run/sshd
chmod 755 /run/sshd
log "✓ /run/sshd created"

# ──────────────────────────────────────────────────────────────────────
# Runtime directories
# ──────────────────────────────────────────────────────────────────────
mkdir -p /run/nginx
log "✓ /run/nginx created"

mkdir -p /run/postgresql
chown postgres:postgres /run/postgresql
chmod 755 /run/postgresql
log "✓ /run/postgresql created"

# ──────────────────────────────────────────────────────────────────────
# PostgreSQL: start cluster
# Ubuntu/Debian uses pg_ctlcluster; postgresql.service is a dummy unit
# ──────────────────────────────────────────────────────────────────────
log "Starting PostgreSQL cluster..."
if command -v pg_ctlcluster >/dev/null 2>&1; then
    pg_ctlcluster 18 main start || true
else
    service postgresql start || true
fi

log "Waiting for PostgreSQL to become ready..."
for i in {1..30}; do
    if sudo -u postgres psql -c '\q' 2>/dev/null; then
        log "✓ PostgreSQL is ready"
        break
    fi
    log "Waiting... ($i/30)"
    sleep 1
done

# ──────────────────────────────────────────────────────────────────────
# PostgreSQL: idempotent role creation
# NOTE: DO $$ blocks are fine for roles
# ──────────────────────────────────────────────────────────────────────
log "Ensuring sonar role exists..."
sudo -u postgres psql -v ON_ERROR_STOP=1 <<'EOF'
DO
$$
BEGIN
   IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sonar') THEN
      CREATE ROLE sonar WITH LOGIN ENCRYPTED PASSWORD 'sonar_password';
   END IF;
END
$$;
EOF
log "✓ Role sonar ensured"

# ──────────────────────────────────────────────────────────────────────
# PostgreSQL: idempotent database creation
# NOTE: CREATE DATABASE cannot run inside a DO $$ block — shell check
# ──────────────────────────────────────────────────────────────────────
log "Ensuring sonarqube database exists..."
DB_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='sonarqube'" 2>/dev/null || echo "0")
if [ "${DB_EXISTS}" != "1" ]; then
    log "Creating sonarqube database..."
    sudo -u postgres psql -v ON_ERROR_STOP=1 -c \
        "CREATE DATABASE sonarqube OWNER sonar ENCODING 'UTF8' LC_COLLATE 'C.UTF-8' LC_CTYPE 'C.UTF-8' TEMPLATE template0;"
    log "✓ Database sonarqube created"
else
    log "Database sonarqube already exists"
fi

sudo -u postgres psql -v ON_ERROR_STOP=1 -c \
    "GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;"
log "✓ Privileges granted to sonar"

# ──────────────────────────────────────────────────────────────────────
# SonarQube: home permissions
# ──────────────────────────────────────────────────────────────────────
if [ -d /opt/sonarqube ]; then
    chown -R sonar:sonar /opt/sonarqube
    chmod 755 /opt/sonarqube
    log "✓ SonarQube home permissions set"
fi

# ──────────────────────────────────────────────────────────────────────
# Elasticsearch: system limits
# ──────────────────────────────────────────────────────────────────────
sysctl -w vm.max_map_count=524288 2>/dev/null || true
sysctl -w fs.file-max=131072 2>/dev/null || true
log "✓ System limits applied"

log "✓ Initialization complete. systemd will now start services."
