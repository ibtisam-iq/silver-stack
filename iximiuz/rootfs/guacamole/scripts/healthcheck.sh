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
