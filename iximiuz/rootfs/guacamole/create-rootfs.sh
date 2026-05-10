#!/bin/bash
set -euo pipefail
#######################################################################
# create-rootfs.sh
# Creates the complete Apache Guacamole rootfs directory structure
# with all scripts, configs, and Dockerfile in one shot.
# Usage:  bash create-rootfs.sh [TARGET_DIR]
#         TARGET_DIR defaults to ./guacamole
# Author: Muhammad Ibtisam Iqbal
#######################################################################

TARGET="${1:-./guacamole}"

log()  { echo "[$(date +'%Y-%m-%d %H:%M:%S')]  $1"; }
ok()   { echo "  ✓ $1"; }
fail() { echo "  ✗ $1"; exit 1; }

log "Creating Guacamole rootfs at: ${TARGET}"

# ── Directories ───────────────────────────────────────────────────────────────
mkdir -p "${TARGET}/scripts"
mkdir -p "${TARGET}/configs/systemd"
mkdir -p "${TARGET}/configs/sudoers.d"
mkdir -p "${TARGET}/configs/xrdp"
mkdir -p "${TARGET}/configs/nginx"
ok "Directory structure created"


# ── Dockerfile ──
cat > "${TARGET}/Dockerfile" << 'ROOTFS_EOF'
# syntax=docker/dockerfile:1
# Guacamole Browser-based Desktop Rootfs
# Base:       ubuntu-24-04-rootfs (systemd-enabled)
# Desktop:    XFCE4 + XRDP + PipeWire audio
# Browser:    Mozilla Firefox (official apt repo)
# Gateway:    Apache Guacamole 1.6.0 (native, no Docker)
# Database:   MariaDB
# Web:        Tomcat 10 + Nginx reverse proxy
# Tunnel:     cloudflared (Cloudflare Tunnel)

FROM ghcr.io/ibtisam-iq/ubuntu-24-04-rootfs:latest
USER root

# ── Build arguments ───────────────────────────────────────────────────────────
ARG USER
ARG GUAC_PORT
ARG GUAC_VERSION
ARG MYSQL_CONNECTOR_VERSION
ARG RDP_USER
ARG RDP_PORT
ARG DB_NAME
ARG DB_USER
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}"

# ── Environment variables (runtime-visible) ───────────────────────────────────
ENV DEBIAN_FRONTEND=noninteractive \
    GUAC_VERSION=${GUAC_VERSION:-1.6.0} \
    MYSQL_CONNECTOR_VERSION=${MYSQL_CONNECTOR_VERSION:-9.2.0} \
    GUAC_PORT=${GUAC_PORT:-8080} \
    RDP_USER=${RDP_USER:-musk} \
    RDP_PORT=${RDP_PORT:-3389} \
    DB_NAME=${DB_NAME:-guacamole_db} \
    DB_USER=${DB_USER:-guacamole_user} \
    GUACAMOLE_HOME=/etc/guacamole \
    TZ=UTC

# ── Copy scripts and configs ──────────────────────────────────────────────────
COPY scripts/ /opt/guacamole-scripts/
RUN chmod +x /opt/guacamole-scripts/*.sh

COPY configs/systemd/lab-init.service     /etc/systemd/system/lab-init.service
COPY configs/systemd/guacamole.service    /etc/systemd/system/guacamole.service
COPY configs/sudoers.d/guacamole-user     /etc/sudoers.d/guacamole-user

COPY configs/nginx/guacamole.conf        /etc/nginx/sites-available/guacamole

# ── Phase 1: Install desktop (XFCE4 + XRDP + Firefox + PipeWire) ─────────────
RUN /opt/guacamole-scripts/install-desktop.sh

COPY configs/xrdp/startwm.sh             /etc/xrdp/startwm.sh

# ── Phase 2: Configure XRDP ───────────────────────────────────────────────────
RUN /opt/guacamole-scripts/configure-xrdp.sh "${RDP_USER}" "${RDP_PORT}"

# ── Phase 3: Install Guacamole native (guacd + WAR + MariaDB + JDBC) ─────────
RUN /opt/guacamole-scripts/install-guacamole.sh \
    "${GUAC_VERSION}" "${MYSQL_CONNECTOR_VERSION}"

# ── Phase 4: Configure Guacamole (guacamole.properties + Tomcat symlink) ─────
RUN /opt/guacamole-scripts/configure-guacamole.sh \
    "${DB_NAME}" "${DB_USER}" "${GUAC_PORT}"

# ── Phase 5: Configure Nginx reverse proxy ────────────────────────────────────
RUN sed -i "s/__GUAC_PORT__/${GUAC_PORT}/g" /etc/nginx/sites-available/guacamole && \
    /opt/guacamole-scripts/configure-nginx.sh

# ── Phase 6: Enable all systemd services ─────────────────────────────────────
RUN systemctl enable lab-init && \
    systemctl enable mariadb && \
    systemctl enable tomcat10 && \
    systemctl enable guacd && \
    systemctl enable xrdp && \
    systemctl enable xrdp-sesman && \
    systemctl enable nginx

# ── Phase 7: Build-time health check ─────────────────────────────────────────
RUN /opt/guacamole-scripts/healthcheck.sh "${USER}" "${GUAC_VERSION}"

# ── Phase 8: Install cloudflared ─────────────────────────────────────────────
RUN /opt/guacamole-scripts/install-cloudflared.sh

# ── Fix ownership of $HOME written during build ───────────────────────────────
RUN chown -R ${USER}:${USER} /home/${USER}

# ── Customize shell for interactive user ─────────────────────────────────────
USER $USER
ENV HOME=/home/$USER
COPY welcome $HOME/.welcome
RUN sed -i "s/__GUAC_PORT__/${GUAC_PORT}/g" $HOME/.welcome && \
    sed -i "s/__RDP_USER__/${RDP_USER}/g"  $HOME/.welcome
RUN --mount=type=bind,source=scripts,target=/tmp/scripts \
    bash /tmp/scripts/customize-bashrc.sh

# ── systemd must run as root (PID 1) ─────────────────────────────────────────
USER root
EXPOSE 22 80 ${GUAC_PORT} ${RDP_PORT}
CMD ["/lib/systemd/systemd"]
ROOTFS_EOF
ok "Dockerfile"

# ── configs/xrdp/startwm.sh ──
cat > "${TARGET}/configs/xrdp/startwm.sh" << 'ROOTFS_EOF'
#!/bin/sh
if test -r /etc/profile; then
    . /etc/profile
fi
if test -r ~/.profile; then
    . ~/.profile
fi
export DISPLAY=${DISPLAY:-:10.0}
export DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}
exec dbus-launch --exit-with-session startxfce4
ROOTFS_EOF
chmod +x "${TARGET}/configs/xrdp/startwm.sh"
ok "configs/xrdp/startwm.sh"

# ── configs/systemd/lab-init.service ──
cat > "${TARGET}/configs/systemd/lab-init.service" << 'ROOTFS_EOF'
[Unit]
Description=Guacamole Lab Runtime Initialization
Documentation=https://github.com/ibtisam-iq/silver-stack
DefaultDependencies=no
After=local-fs.target sysinit.target
Before=ssh.service mariadb.service tomcat10.service guacd.service xrdp.service nginx.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/opt/guacamole-scripts/lab-init.sh
StandardOutput=journal
StandardError=journal
TimeoutStartSec=180

[Install]
WantedBy=multi-user.target
ROOTFS_EOF
ok "configs/systemd/lab-init.service"

# ── configs/systemd/guacamole.service ──
cat > "${TARGET}/configs/systemd/guacamole.service" << 'ROOTFS_EOF'
[Unit]
Description=Apache Guacamole Daemon (guacd)
Documentation=https://guacamole.apache.org/
After=network.target lab-init.service
Requires=lab-init.service

[Service]
Type=forking
PIDFile=/var/run/guacd.pid
ExecStart=/usr/local/sbin/guacd -f
ExecStop=/bin/kill -TERM $MAINPID
Restart=on-failure
RestartSec=5
User=daemon
Group=daemon
Environment=HOME=/var/lib/guacd

[Install]
WantedBy=multi-user.target
ROOTFS_EOF
ok "configs/systemd/guacamole.service"

# ── configs/sudoers.d/guacamole-user ──
cat > "${TARGET}/configs/sudoers.d/guacamole-user" << 'ROOTFS_EOF'
# Allow tomcat to read guacamole.properties
# Allow xrdp to manage its socket
# Allow lab-init.service operations at boot
tomcat  ALL=(root) NOPASSWD: /bin/chown tomcat\:tomcat /etc/guacamole/guacamole.properties
ROOTFS_EOF
ok "configs/sudoers.d/guacamole-user"

# ── configs/nginx/guacamole.conf ──
cat > "${TARGET}/configs/nginx/guacamole.conf" << 'ROOTFS_EOF'
# Nginx reverse proxy for Apache Guacamole
# __GUAC_PORT__ is substituted at build time via sed in Dockerfile

upstream guacamole {
    server 127.0.0.1:__GUAC_PORT__;
    keepalive 16;
}

server {
    listen 80;
    server_name _;

    # Security headers
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";

    # Redirect root to /guacamole
    location = / {
        return 301 /guacamole/;
    }

    location /guacamole/ {
        proxy_pass http://guacamole/guacamole/;
        proxy_buffering off;
        proxy_http_version 1.1;

        # WebSocket support (required for Guacamole tunnel)
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_read_timeout 3600;
        proxy_send_timeout 3600;

        # Required for clipboard/file transfer
        client_max_body_size 100M;
    }
}
ROOTFS_EOF
ok "configs/nginx/guacamole.conf"

# ── scripts/install-desktop.sh ──
cat > "${TARGET}/scripts/install-desktop.sh" << 'ROOTFS_EOF'
#!/bin/bash
set -euo pipefail
#######################################################################
# install-desktop.sh
# Installs XFCE4 desktop, TigerVNC, PipeWire audio, and Mozilla Firefox
# Called at Docker build time — no systemd running
# Author: Muhammad Ibtisam Iqbal
#######################################################################

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

log "==> Installing XFCE4 desktop environment..."
apt-get update -y
apt-get install -y \
    xfce4 xfce4-goodies \
    tigervnc-standalone-server \
    tigervnc-common \
    dbus-x11 \
    x11-xserver-utils
log "✓ XFCE4 installed"

log "==> Installing PipeWire audio stack..."
apt-get install -y \
    pipewire \
    pipewire-pulse \
    pipewire-audio \
    wireplumber \
    pipewire-alsa
log "✓ PipeWire audio installed"

log "==> Installing XRDP..."
apt-get install -y xrdp
log "✓ XRDP installed"

log "==> Installing Mozilla Firefox from official apt repo..."
snap remove firefox 2>/dev/null || true
apt-get remove --purge -y firefox 2>/dev/null || true

install -d -m 0755 /etc/apt/keyrings
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- \
    | tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null

echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] \
https://packages.mozilla.org/apt mozilla main" \
    | tee /etc/apt/sources.list.d/mozilla.list > /dev/null

echo -e "Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000" \
    | tee /etc/apt/preferences.d/mozilla > /dev/null

apt-get update -y
apt-get install -y firefox
log "✓ Mozilla Firefox installed"
ROOTFS_EOF
chmod +x "${TARGET}/scripts/install-desktop.sh"
ok "scripts/install-desktop.sh"

# ── scripts/configure-xrdp.sh ──
cat > "${TARGET}/scripts/configure-xrdp.sh" << 'ROOTFS_EOF'
#!/bin/bash
set -euo pipefail
#######################################################################
# configure-xrdp.sh
# Configures XRDP for XFCE4 sessions:
#   - Sets key.pem permissions
#   - Writes startwm.sh (already copied via Dockerfile COPY)
#   - Writes .xsession for the RDP desktop user
#   - Fixes /run/xrdp tmpfiles for boot persistence
#   - Sets security_layer=rdp (avoids SSL mismatch with guacd)
# Arguments:
#   $1 - RDP_USER  (desktop user, e.g. musk)
#   $2 - RDP_PORT  (default: 3389)
# Author: Muhammad Ibtisam Iqbal
#######################################################################

RDP_USER="${1:?RDP_USER required}"
RDP_PORT="${2:-3389}"

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

log "==> Configuring XRDP permissions..."
chmod 640 /etc/xrdp/key.pem
chown root:xrdp /etc/xrdp/key.pem
adduser xrdp ssl-cert 2>/dev/null || true
chmod +x /etc/xrdp/startwm.sh
log "✓ XRDP key.pem and startwm.sh configured"

log "==> Setting xrdp security_layer=rdp (required for guacd compatibility)..."
sed -i 's/^security_layer=.*/security_layer=rdp/' /etc/xrdp/xrdp.ini
log "✓ security_layer=rdp set"

log "==> Ensuring RDP user '${RDP_USER}' exists..."
id "${RDP_USER}" &>/dev/null || useradd -m -s /bin/bash "${RDP_USER}"
usermod -aG sudo "${RDP_USER}" 2>/dev/null || true
log "✓ User '${RDP_USER}' ensured"

log "==> Creating .xsession for ${RDP_USER}..."
mkdir -p "/home/${RDP_USER}"
cat > "/home/${RDP_USER}/.xsession" << 'INNEREOF'
#!/bin/bash
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=XFCE
export DISPLAY=${DISPLAY:-:10.0}
exec dbus-launch --exit-with-session startxfce4
INNEREOF
chmod +x "/home/${RDP_USER}/.xsession"
chown "${RDP_USER}:${RDP_USER}" "/home/${RDP_USER}/.xsession"
log "✓ .xsession written for ${RDP_USER}"

log "==> Configuring /run/xrdp tmpfiles (boot persistence)..."
mkdir -p /run/xrdp
chown xrdp:xrdp /run/xrdp
chmod 755 /run/xrdp
echo "d /run/xrdp 0755 xrdp xrdp -" | tee /etc/tmpfiles.d/xrdp.conf
mkdir -p /tmp/.xrdp
chmod 1777 /tmp/.xrdp
log "✓ /run/xrdp tmpfiles configured"
ROOTFS_EOF
chmod +x "${TARGET}/scripts/configure-xrdp.sh"
ok "scripts/configure-xrdp.sh"

# ── scripts/install-guacamole.sh ──
cat > "${TARGET}/scripts/install-guacamole.sh" << 'ROOTFS_EOF'
#!/bin/bash
set -euo pipefail
#######################################################################
# install-guacamole.sh
# Installs Apache Guacamole natively (no Docker):
#   - Build dependencies + Tomcat 10 + MariaDB
#   - guacamole-server (guacd) compiled from source
#   - guacamole-client WAR converted for Tomcat 10 (javax→jakarta)
#   - JDBC MySQL auth extension (converted for Jakarta)
#   - MySQL Connector/J
# Arguments:
#   $1 - GUAC_VERSION            (e.g. 1.6.0)
#   $2 - MYSQL_CONNECTOR_VERSION (e.g. 9.2.0)
# Author: Muhammad Ibtisam Iqbal
#######################################################################

GUAC_VERSION="${1:?GUAC_VERSION required}"
MYSQL_CONNECTOR_VERSION="${2:?MYSQL_CONNECTOR_VERSION required}"

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

# ── Build dependencies ────────────────────────────────────────────────────────
log "==> Installing Guacamole build dependencies..."
apt-get install -y \
    build-essential \
    libcairo2-dev \
    libjpeg-turbo8-dev \
    libpng-dev \
    libtool-bin \
    uuid-dev \
    libossp-uuid-dev \
    libvncserver-dev \
    freerdp2-dev \
    libssh2-1-dev \
    libssl-dev \
    libtelnet-dev \
    libpango1.0-dev \
    libwebsockets-dev \
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    libswscale-dev \
    libvorbis-dev \
    libwebp-dev \
    libpulse-dev \
    tomcat10 \
    mariadb-server \
    tomcat-jakartaee-migration \
    wget \
    curl
log "✓ Build dependencies installed"

# ── Build guacamole-server (guacd) from source ────────────────────────────────
log "==> Downloading guacamole-server ${GUAC_VERSION}..."
cd /tmp
wget -q "https://downloads.apache.org/guacamole/${GUAC_VERSION}/source/guacamole-server-${GUAC_VERSION}.tar.gz"
tar -xzf "guacamole-server-${GUAC_VERSION}.tar.gz"
cd "guacamole-server-${GUAC_VERSION}"

log "==> Configuring guacamole-server..."
./configure --with-systemd-dir=/etc/systemd/system/

log "==> Compiling guacamole-server (using $(nproc) cores)..."
make -j"$(nproc)"
make install
ldconfig
log "✓ guacd installed to /usr/local/sbin/guacd"

# ── Deploy guacamole-client WAR (javax→jakarta for Tomcat 10) ─────────────────
log "==> Downloading guacamole-client WAR ${GUAC_VERSION}..."
cd /tmp
wget -q "https://downloads.apache.org/guacamole/${GUAC_VERSION}/binary/guacamole-${GUAC_VERSION}.war"

log "==> Converting WAR from javax→jakarta namespace (Tomcat 10 requirement)..."
javax2jakarta \
    "/tmp/guacamole-${GUAC_VERSION}.war" \
    "/var/lib/tomcat10/webapps/guacamole.war"
log "✓ guacamole.war deployed to Tomcat 10 webapps"

# ── JDBC auth extension ───────────────────────────────────────────────────────
log "==> Downloading guacamole-auth-jdbc ${GUAC_VERSION}..."
cd /tmp
wget -q "https://downloads.apache.org/guacamole/${GUAC_VERSION}/binary/guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz"
tar -xzf "guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz"

mkdir -p /etc/guacamole/extensions
mkdir -p /etc/guacamole/lib

log "==> Converting JDBC JAR from javax→jakarta namespace..."
javax2jakarta \
    "/tmp/guacamole-auth-jdbc-${GUAC_VERSION}/mysql/guacamole-auth-jdbc-mysql-${GUAC_VERSION}.jar" \
    "/etc/guacamole/extensions/guacamole-auth-jdbc-mysql-${GUAC_VERSION}.jar"
log "✓ JDBC auth extension installed"

# ── MySQL Connector/J ─────────────────────────────────────────────────────────
log "==> Downloading MySQL Connector/J ${MYSQL_CONNECTOR_VERSION}..."
cd /tmp
wget -q "https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-j-${MYSQL_CONNECTOR_VERSION}.tar.gz"
tar -xzf "mysql-connector-j-${MYSQL_CONNECTOR_VERSION}.tar.gz"
cp "mysql-connector-j-${MYSQL_CONNECTOR_VERSION}/mysql-connector-j-${MYSQL_CONNECTOR_VERSION}.jar" \
    /etc/guacamole/lib/
log "✓ MySQL Connector/J installed"

# ── Store schema SQL for lab-init to import at first boot ────────────────────
mkdir -p /opt/guacamole-schema
cp /tmp/guacamole-auth-jdbc-${GUAC_VERSION}/mysql/schema/*.sql /opt/guacamole-schema/
log "✓ Schema SQL stored in /opt/guacamole-schema/"

log "✓ Guacamole installation complete"
ROOTFS_EOF
chmod +x "${TARGET}/scripts/install-guacamole.sh"
ok "scripts/install-guacamole.sh"

# ── scripts/configure-guacamole.sh ──
cat > "${TARGET}/scripts/configure-guacamole.sh" << 'ROOTFS_EOF'
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
ROOTFS_EOF
chmod +x "${TARGET}/scripts/configure-guacamole.sh"
ok "scripts/configure-guacamole.sh"

# ── scripts/configure-nginx.sh ──
cat > "${TARGET}/scripts/configure-nginx.sh" << 'ROOTFS_EOF'
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
ROOTFS_EOF
chmod +x "${TARGET}/scripts/configure-nginx.sh"
ok "scripts/configure-nginx.sh"

# ── scripts/lab-init.sh ──
cat > "${TARGET}/scripts/lab-init.sh" << 'ROOTFS_EOF'
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
ROOTFS_EOF
chmod +x "${TARGET}/scripts/lab-init.sh"
ok "scripts/lab-init.sh"

# ── scripts/healthcheck.sh ──
cat > "${TARGET}/scripts/healthcheck.sh" << 'ROOTFS_EOF'
#!/bin/bash
set -euo pipefail
#######################################################################
# healthcheck.sh
# Build-time validation — runs inside Docker during image build.
# systemd is NOT running; services verified via symlinks + binaries.
#
# Sections:
#   [1]  System tools
#   [2]  Desktop environment (XFCE4, TigerVNC, PipeWire)
#   [3]  XRDP
#   [4]  Firefox
#   [5]  guacd (Guacamole daemon)
#   [6]  Tomcat 10
#   [7]  MariaDB
#   [8]  Guacamole extensions and config
#   [9]  Nginx configuration
#   [10] Systemd services enabled
#   [11] User configuration
#   [12] cloudflared
#
# Arguments:
#   $1 - INTERACTIVE_USER  (e.g. ibtisam)
#   $2 - GUAC_VERSION      (e.g. 1.6.0)
#
# Author: Muhammad Ibtisam Iqbal
#######################################################################

INTERACTIVE_USER="${1:-$(basename "$HOME")}"
GUAC_VERSION="${2:-1.6.0}"
FAILURES=0

echo "==============================="
echo " Guacamole Rootfs Health Check"
echo "==============================="
echo ""

check_command() {
    local cmd="$1" name="${2:-$1}"
    if command -v "$cmd" &>/dev/null; then
        echo "✓ ${name}: $(${cmd} --version 2>&1 | head -1)"
    else
        echo "✗ ${name}: Not found"
        FAILURES=$((FAILURES + 1))
    fi
}

check_file() {
    local file="$1" name="${2:-$1}"
    if [ -f "$file" ]; then
        echo "✓ File: ${name}"
    else
        echo "✗ File missing: ${name}"
        FAILURES=$((FAILURES + 1))
    fi
}

check_dir() {
    local dir="$1" name="${2:-$1}"
    if [ -d "$dir" ]; then
        echo "✓ Dir:  ${name}"
    else
        echo "✗ Dir missing: ${name}"
        FAILURES=$((FAILURES + 1))
    fi
}

check_service() {
    local svc="$1"
    local link="/etc/systemd/system/multi-user.target.wants/${svc}.service"
    if [ -L "$link" ]; then
        echo "✓ Service enabled: ${svc}"
    else
        echo "✗ Service NOT enabled: ${svc}"
        FAILURES=$((FAILURES + 1))
    fi
}

check_package() {
    local pkg="$1" name="${2:-$1}"
    if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
        local ver; ver=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null)
        echo "✓ Package: ${name} (${ver})"
    else
        echo "✗ Package missing: ${name}"
        FAILURES=$((FAILURES + 1))
    fi
}

check_user() {
    local u="$1"
    if id "$u" &>/dev/null; then
        echo "✓ User: ${u} (UID=$(id -u "$u"))"
    else
        echo "✗ User missing: ${u}"
        FAILURES=$((FAILURES + 1))
    fi
}

# ── [1] System tools ──────────────────────────────────────────────────────────
echo "[1] System Tools"
echo "-----------------------------------"
check_command curl
check_command wget
check_command git
check_command openssl
echo ""

# ── [2] Desktop environment ───────────────────────────────────────────────────
echo "[2] Desktop Environment"
echo "-----------------------------------"
check_package "xfce4"            "XFCE4"
check_package "tigervnc-standalone-server" "TigerVNC"
check_package "pipewire"         "PipeWire"
check_package "dbus-x11"         "dbus-x11"
echo ""

# ── [3] XRDP ──────────────────────────────────────────────────────────────────
echo "[3] XRDP"
echo "-----------------------------------"
check_command xrdp
check_file "/etc/xrdp/xrdp.ini"     "xrdp.ini"
check_file "/etc/xrdp/startwm.sh"   "startwm.sh"
check_file "/etc/tmpfiles.d/xrdp.conf" "xrdp tmpfiles.conf"
if grep -q "security_layer=rdp" /etc/xrdp/xrdp.ini 2>/dev/null; then
    echo "✓ xrdp security_layer=rdp (guacd-compatible)"
else
    echo "⚠ xrdp security_layer not set to rdp"
fi
echo ""

# ── [4] Firefox ───────────────────────────────────────────────────────────────
echo "[4] Firefox"
echo "-----------------------------------"
check_command firefox
check_file "/etc/apt/keyrings/packages.mozilla.org.asc" "Mozilla apt key"
echo ""

# ── [5] guacd ────────────────────────────────────────────────────────────────
echo "[5] guacd (Guacamole daemon)"
echo "-----------------------------------"
check_command guacd
check_file "/usr/local/sbin/guacd" "guacd binary"
check_file "/etc/systemd/system/guacd.service" "guacd.service"
echo ""

# ── [6] Tomcat 10 ─────────────────────────────────────────────────────────────
echo "[6] Tomcat 10"
echo "-----------------------------------"
check_package "tomcat10" "Tomcat 10"
check_file "/var/lib/tomcat10/webapps/guacamole.war" "guacamole.war"
check_dir  "/var/lib/tomcat10/webapps" "Tomcat webapps"
echo ""

# ── [7] MariaDB ───────────────────────────────────────────────────────────────
echo "[7] MariaDB"
echo "-----------------------------------"
check_package "mariadb-server" "MariaDB Server"
check_command mysql
check_command mysqladmin
echo ""

# ── [8] Guacamole config and extensions ──────────────────────────────────────
echo "[8] Guacamole Config & Extensions"
echo "-----------------------------------"
check_dir  "/etc/guacamole"            "GUACAMOLE_HOME"
check_dir  "/etc/guacamole/extensions" "extensions/"
check_dir  "/etc/guacamole/lib"        "lib/"
check_file "/etc/guacamole/guacamole.properties" "guacamole.properties"

EXT_JAR=$(ls /etc/guacamole/extensions/guacamole-auth-jdbc-mysql-*.jar 2>/dev/null | head -1)
if [ -n "$EXT_JAR" ]; then
    echo "✓ JDBC ext: $(basename "$EXT_JAR")"
else
    echo "✗ JDBC auth extension missing"
    FAILURES=$((FAILURES + 1))
fi

CONN_JAR=$(ls /etc/guacamole/lib/mysql-connector-j-*.jar 2>/dev/null | head -1)
if [ -n "$CONN_JAR" ]; then
    echo "✓ Connector: $(basename "$CONN_JAR")"
else
    echo "✗ MySQL Connector/J missing"
    FAILURES=$((FAILURES + 1))
fi

if [ -L /var/lib/tomcat10/.guacamole ]; then
    echo "✓ Tomcat .guacamole symlink: present"
else
    echo "✗ Tomcat .guacamole symlink: missing"
    FAILURES=$((FAILURES + 1))
fi

check_dir "/opt/guacamole-schema" "Schema SQL dir"

if grep -q "__DB_PASS__" /etc/guacamole/guacamole.properties 2>/dev/null; then
    echo "✓ guacamole.properties: DB password placeholder set (injected at boot)"
else
    echo "⚠ guacamole.properties: __DB_PASS__ placeholder not found"
fi
echo ""

# ── [9] Nginx ─────────────────────────────────────────────────────────────────
echo "[9] Nginx"
echo "-----------------------------------"
check_command nginx
check_file "/etc/nginx/sites-available/guacamole" "nginx guacamole site"
if [ -L /etc/nginx/sites-enabled/guacamole ]; then
    echo "✓ guacamole site: enabled"
else
    echo "✗ guacamole site: NOT enabled"
    FAILURES=$((FAILURES + 1))
fi
if [ ! -f /etc/nginx/sites-enabled/default ]; then
    echo "✓ default nginx site: removed"
else
    echo "⚠ default nginx site: still present"
fi
nginx -t 2>/dev/null && echo "✓ nginx config: valid" || { echo "✗ nginx config: invalid"; FAILURES=$((FAILURES + 1)); }
echo ""

# ── [10] Systemd services enabled ────────────────────────────────────────────
echo "[10] Systemd Services"
echo "-----------------------------------"
check_service "lab-init"
check_service "ssh"
check_service "mariadb"
check_service "tomcat10"
check_service "guacd"
check_service "xrdp"
check_service "xrdp-sesman"
check_service "nginx"
echo ""

# ── [11] Users ────────────────────────────────────────────────────────────────
echo "[11] User Configuration"
echo "-----------------------------------"
check_user "${INTERACTIVE_USER}"
check_file "/etc/sudoers.d/guacamole-user" "sudoers guacamole-user"
echo ""

# ── [12] cloudflared ─────────────────────────────────────────────────────────
echo "[12] cloudflared"
echo "-----------------------------------"
check_command cloudflared
echo ""

# ── Result ────────────────────────────────────────────────────────────────────
echo "==============================="
if [ "${FAILURES}" -eq 0 ]; then
    echo "✓ All health checks passed!"
else
    echo "✗ ${FAILURES} check(s) FAILED"
fi
echo "==============================="
exit "${FAILURES}"
ROOTFS_EOF
chmod +x "${TARGET}/scripts/healthcheck.sh"
ok "scripts/healthcheck.sh"

# ── scripts/customize-bashrc.sh ──
cat > "${TARGET}/scripts/customize-bashrc.sh" << 'ROOTFS_EOF'
#!/bin/bash
set -euo pipefail
#######################################################################
# customize-bashrc.sh
# Appends Guacamole/XRDP/MariaDB/Tomcat/nginx aliases and the
# welcome banner trigger to the interactive user's ~/.bashrc.
# Runs as the interactive user (not root) during Docker build.
# Author: Muhammad Ibtisam Iqbal
#######################################################################

BASHRC="${HOME}/.bashrc"

cat >> "${BASHRC}" << 'EOF'

# ── Guacamole Desktop Playground ─────────────────────────────────────────────
if [ -f ~/.welcome ] && [ -z "${WELCOME_SHOWN:-}" ]; then
    cat ~/.welcome
    export WELCOME_SHOWN=1
fi

# Service shortcuts
alias guac-status='sudo systemctl status guacd tomcat10 mariadb xrdp nginx --no-pager'
alias guac-restart='sudo systemctl restart guacd tomcat10'
alias guac-logs='sudo journalctl -u tomcat10 -f'
alias guacd-logs='sudo journalctl -u guacd -f'
alias xrdp-logs='sudo journalctl -u xrdp -f'
alias nginx-logs='sudo tail -f /var/log/nginx/access.log /var/log/nginx/error.log'

# Quick DB access
alias guac-db='sudo mysql guacamole_db'
alias guac-connections="sudo mysql guacamole_db -e 'SELECT connection_id, connection_name, protocol FROM guacamole_connection;'"

# Config shortcuts
alias guac-conf='sudo cat /etc/guacamole/guacamole.properties'
alias guac-props='sudo vim /etc/guacamole/guacamole.properties'
alias nginx-conf='sudo cat /etc/nginx/sites-available/guacamole'

# Port summary
alias ports='ss -lntp | grep -E "22|80|3389|4822|8080|3306"'
EOF

echo "✓ bashrc customized for $(whoami)"
ROOTFS_EOF
chmod +x "${TARGET}/scripts/customize-bashrc.sh"
ok "scripts/customize-bashrc.sh"

# ── scripts/install-cloudflared.sh ──
cat > "${TARGET}/scripts/install-cloudflared.sh" << 'ROOTFS_EOF'
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
ROOTFS_EOF
chmod +x "${TARGET}/scripts/install-cloudflared.sh"
ok "scripts/install-cloudflared.sh"

# ── welcome ──
cat > "${TARGET}/welcome" << 'ROOTFS_EOF'

╔══════════════════════════════════════════════════════════════════════╗
║        Apache Guacamole — Browser-based Desktop Playground           ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  Guacamole UI    http://localhost:__GUAC_PORT__/guacamole            ║
║  Login           guacadmin / guacadmin                               ║
║  RDP Desktop     __RDP_USER__ (password shown in lab-init logs)      ║
║                                                                      ║
║  Cloudflare Tunnel (public access with SSL):                         ║
║    cloudflared tunnel --url http://localhost:__GUAC_PORT__           ║
║                                                                      ║
╠══════════════════════════════════════════════════════════════════════╣
║  Quick commands:                                                     ║
║    guac-status     — status of all 6 services                        ║
║    guac-logs       — Tomcat live logs                                ║
║    guacd-logs      — guacd live logs                                 ║
║    xrdp-logs       — XRDP live logs                                  ║
║    guac-db         — MySQL shell → guacamole_db                      ║
║    ports           — show all listening ports                        ║
╚══════════════════════════════════════════════════════════════════════╝
ROOTFS_EOF
ok "welcome"

# ── README.md ──
cat > "${TARGET}/README.md" << 'ROOTFS_EOF'
# Apache Guacamole Desktop Rootfs

Production-grade Apache Guacamole rootfs for iximiuz playgrounds. Boots
MariaDB → guacd → Tomcat 10 → XRDP → Nginx via systemd with `cloudflared`
pre-installed for instant public access with SSL via Cloudflare Tunnel.

## What It Is

A child image built on top of [`ubuntu-24-04-rootfs`](https://github.com/ibtisam-iq/silver-stack/blob/main/iximiuz/rootfs/ubuntu/README.md).
On first boot, systemd starts `lab-init` → `mariadb` → `tomcat10` → `guacd` → `xrdp` → `nginx` in order.
`lab-init` creates the MariaDB database, imports the Guacamole schema, pre-seeds the RDP connection,
and injects runtime credentials — no manual setup required. Guacamole is accessible on port 80 via Nginx.

## What's Inside

| Component       | Version        | Detail                                              |
|-----------------|----------------|-----------------------------------------------------|
| Base            | `ubuntu-24-04-rootfs` | systemd-enabled Ubuntu 24.04              |
| XFCE4           | Latest apt     | Desktop environment for RDP sessions                |
| XRDP            | Latest apt     | RDP server; `security_layer=rdp` for guacd compat  |
| Firefox         | Latest (Mozilla repo) | Pre-installed browser in desktop session   |
| PipeWire        | Latest apt     | Audio stack for RDP audio forwarding                |
| guacd           | 1.6.0          | Guacamole proxy daemon (built from source)          |
| Tomcat 10       | Latest apt     | Serves guacamole.war (Jakarta EE namespace)         |
| MariaDB         | Latest apt     | Database for Guacamole auth + connections           |
| Nginx           | Latest apt     | Reverse proxy → port 80, WebSocket-aware            |
| cloudflared     | Latest         | Cloudflare Tunnel client                            |

## Directory Structure

```
guacamole/
├── Dockerfile
├── README.md
├── welcome
├── configs/
│   ├── nginx/
│   │   └── guacamole.conf       # Upstream: 127.0.0.1:__GUAC_PORT__; WebSocket support
│   ├── systemd/
│   │   ├── lab-init.service     # oneshot: Before=mariadb,tomcat10,guacd,xrdp,nginx
│   │   └── guacamole.service    # guacd override unit (ordering + HOME env)
│   ├── sudoers.d/
│   │   └── guacamole-user       # Limited sudo for tomcat
│   └── xrdp/
│       └── startwm.sh           # XFCE4 session launcher for XRDP
└── scripts/
    ├── install-desktop.sh       # XFCE4 + TigerVNC + PipeWire + Firefox
    ├── configure-xrdp.sh        # Permissions, security_layer=rdp, .xsession
    ├── install-guacamole.sh     # guacd source build + WAR + JDBC + Connector/J
    ├── configure-guacamole.sh   # guacamole.properties (DB pass placeholder)
    ├── configure-nginx.sh       # Enable guacamole site, remove default
    ├── lab-init.sh              # Boot: MariaDB init, schema, RDP seed, credential inject
    ├── healthcheck.sh           # Build-time validation (12 sections)
    ├── customize-bashrc.sh      # Aliases + welcome banner → ~/.bashrc
    └── install-cloudflared.sh   # Cloudflare Tunnel CLI
```

## Build Arguments

| ARG                      | CI Default       | Description                                               |
|--------------------------|------------------|-----------------------------------------------------------|
| `USER`                   | `ibtisam`        | Interactive non-root user (from base image)               |
| `GUAC_VERSION`           | `1.6.0`          | Guacamole server + client version                         |
| `MYSQL_CONNECTOR_VERSION`| `9.2.0`          | MySQL Connector/J version                                 |
| `GUAC_PORT`              | `8080`           | Tomcat HTTP port — substituted in nginx.conf + welcome    |
| `RDP_USER`               | `musk`        | XRDP desktop username — pre-seeded in DB at build time    |
| `RDP_PORT`               | `3389`           | XRDP listen port                                          |
| `DB_NAME`                | `guacamole_db`   | MariaDB database name                                     |
| `DB_USER`                | `guacamole_user` | MariaDB username                                          |
| `BUILD_DATE`             | CI-injected      | OCI label: image creation timestamp                       |
| `VCS_REF`                | `github.sha`     | OCI label: git commit SHA                                 |

## Runtime Environment Variables

All variables have safe defaults. Override via `docker run -e` or iximiuz env:

| Variable                 | Default (auto-generated if blank) | Description                   |
|--------------------------|-----------------------------------|-------------------------------|
| `DB_PASS`                | `openssl rand` 20 chars           | MariaDB password for DB_USER  |
| `RDP_PASS`               | `openssl rand` 12 chars           | XRDP desktop user password    |
| `DB_NAME`                | `guacamole_db`                    | Override MariaDB database name|
| `DB_USER`                | `guacamole_user`                  | Override MariaDB username      |
| `RDP_USER`               | `musk`                         | Override XRDP desktop user    |
| `RDP_PORT`               | `3389`                            | Override XRDP port            |
| `GUAC_PORT`              | `8080`                            | Override Tomcat port          |

## Boot Sequence

```
systemd (PID 1)
└── lab-init.service [oneshot]
      Generates SSH host keys
      Creates /run/sshd, /run/nginx, /run/xrdp
      Starts temporary MariaDB → creates DB + user (idempotent)
      Imports Guacamole schema (idempotent)
      Pre-seeds XFCE Desktop RDP connection (idempotent)
      Sets RDP_USER password
      Injects DB_PASS into guacamole.properties
      ↓
└── mariadb.service
      ↓
└── tomcat10.service
      Loads guacamole.war + JDBC extension
      ↓
└── guacd.service
      Listens on :4822
      ↓
└── xrdp.service + xrdp-sesman.service
      Listens on :3389 (security_layer=rdp)
      ↓
└── nginx.service
      Listens on :80 → proxies to 127.0.0.1:GUAC_PORT
```

> Guacamole/Tomcat takes **30–60 seconds** to fully initialize on first boot.

## Local Build

```bash
docker build \
  --build-arg USER=ibtisam \
  --build-arg GUAC_VERSION=1.6.0 \
  --build-arg MYSQL_CONNECTOR_VERSION=9.2.0 \
  --build-arg GUAC_PORT=8080 \
  --build-arg RDP_USER=musk \
  --build-arg RDP_PORT=3389 \
  --build-arg DB_NAME=guacamole_db \
  --build-arg DB_USER=guacamole_user \
  -t ghcr.io/ibtisam-iq/guacamole-rootfs:latest \
  .
```

## Usage in an iximiuz Playground

```bash
labctl playground create --base flexbox guacamole-desktop -f guacamole-desktop.yml
```

## Notes

- **`security_layer=rdp`** in `/etc/xrdp/xrdp.ini` is mandatory — guacd's `security=rdp`
  connection parameter requires this to avoid SSL handshake failure.
- **DB password** is never baked into the image — `__DB_PASS__` placeholder is injected
  by `lab-init.sh` at each boot, so credentials are ephemeral per VM.
- **Schema import is idempotent** — safe to reboot without re-importing.
ROOTFS_EOF
ok "README.md"


# ── Final summary ─────────────────────────────────────────────────────────────
log "============================================================"
log " Guacamole rootfs created at: ${TARGET}"
log ""
log " File tree:"
find "${TARGET}" | sort | sed 's|'"${TARGET}"'||' | sed 's|^/||' | \
    awk '{
        depth = gsub(/\//, "/");
        n = split($0, parts, "/");
        indent = "";
        for (i=1; i<n; i++) indent = indent "    ";
        print indent (n>1 ? "├── " : "") parts[n]
    }'
log "============================================================"
log "✓ Done. Next: docker build -t guacamole-rootfs:latest ${TARGET}"
