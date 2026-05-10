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
