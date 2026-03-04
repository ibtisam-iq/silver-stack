#!/bin/bash
set -euo pipefail

#######################################################################
# healthcheck.sh
#
# Performs build-time health checks on the Nexus rootfs image.
#
# NOTE: Runs at BUILD TIME inside Docker.
#   - systemd is NOT running during build
#   - Services verified via symlinks, not systemctl
#   - Packages checked via dpkg-query
#
# Arguments:
#   USER - Interactive user to verify
#
# Exit codes:
#   0 - All checks passed
#   1 - One or more checks failed
#
# Author: Muhammad Ibtisam Iqbal
#######################################################################

INTERACTIVE_USER=${1:-$(basename "$HOME")}
FAILURES=0

echo "==============================="
echo "Running Health Checks"
echo "==============================="
echo ""

check_command() {
    local cmd="${1}" name="${2:-${1}}"
    if command -v "${cmd}" &>/dev/null; then
        echo "✓ ${name}: $("${cmd}" --version 2>&1 | head -n 1)"
    else
        echo "✗ ${name}: Not found"
        FAILURES=$((FAILURES + 1))
    fi
}

check_file() {
    local file="${1}" name="${2:-${1}}"
    if [ -f "${file}" ]; then
        echo "✓ File exists: ${name}"
    else
        echo "✗ File missing: ${name}"
        FAILURES=$((FAILURES + 1))
    fi
}

check_directory() {
    local dir="${1}" name="${2:-${1}}"
    if [ -d "${dir}" ]; then
        echo "✓ Directory exists: ${name}"
    else
        echo "✗ Directory missing: ${name}"
        FAILURES=$((FAILURES + 1))
    fi
}

check_service() {
    local service="${1}"
    local wants_link="/etc/systemd/system/multi-user.target.wants/${service}.service"
    if [ -L "${wants_link}" ]; then
        echo "✓ Systemd service enabled: ${service}"
    else
        echo "✗ Systemd service not enabled: ${service}"
        FAILURES=$((FAILURES + 1))
    fi
}

check_user() {
    local username="${1}"
    if id "${username}" &>/dev/null; then
        echo "✓ User exists: ${username} (UID: $(id -u "${username}"))"
    else
        echo "⚠ User not found: ${username} (will be created at runtime)"
    fi
}

# ---------------------------------------------------------------------

echo "[1] System Tools"
echo "-----------------------------------"
check_command curl "cURL"
check_command wget "wget"
check_command git "Git"
check_command vim "Vim"
if command -v nginx &>/dev/null; then
    echo "✓ Nginx: $(nginx -v 2>&1)"
else
    echo "✗ Nginx: Not found"
    FAILURES=$((FAILURES + 1))
fi
echo ""

echo "[2] Java Installation"
echo "-----------------------------------"
check_command java "Java Runtime"
check_command javac "Java Compiler"
if [ -n "${JAVA_HOME:-}" ]; then
    echo "✓ JAVA_HOME: ${JAVA_HOME}"
else
    echo "✗ JAVA_HOME: Not set"
    FAILURES=$((FAILURES + 1))
fi
echo ""

echo "[3] Nexus Installation"
echo "-----------------------------------"
check_directory "/opt/nexus" "Nexus home"
check_directory "/opt/nexus/bin" "Nexus bin"
check_directory "/opt/sonatype-work" "Nexus data directory"
check_file "/opt/nexus/bin/nexus" "Nexus binary"
check_file "/opt/nexus/bin/nexus.rc" "Nexus run config"
check_user "nexus"

if grep -q 'run_as_user="nexus"' /opt/nexus/bin/nexus.rc 2>/dev/null; then
    echo "✓ Nexus run_as_user: nexus"
else
    echo "✗ Nexus run_as_user: Not set to nexus"
    FAILURES=$((FAILURES + 1))
fi

NEXUS_OWNER=$(stat -c '%U' /opt/nexus 2>/dev/null || echo "unknown")
if [ "${NEXUS_OWNER}" = "nexus" ]; then
    echo "✓ Nexus home ownership: Correct (nexus)"
else
    echo "✗ Nexus home ownership: Incorrect (${NEXUS_OWNER})"
    FAILURES=$((FAILURES + 1))
fi
echo ""

echo "[4] Nexus Port Configuration"
echo "-----------------------------------"
NEXUS_PROPS="/opt/sonatype-work/nexus3/etc/nexus.properties"
check_file "${NEXUS_PROPS}" "nexus.properties"

if grep -q "application-port=${NEXUS_PORT:-8081}" "${NEXUS_PROPS}" 2>/dev/null; then
    echo "✓ application-port: ${NEXUS_PORT:-8081}"
else
    echo "✗ application-port: Expected ${NEXUS_PORT:-8081} not found"
    FAILURES=$((FAILURES + 1))
fi

if grep -q "127.0.0.1:${NEXUS_PORT:-8081}" /etc/nginx/sites-available/nexus 2>/dev/null; then
    echo "✓ Nginx upstream port: ${NEXUS_PORT:-8081}"
else
    echo "✗ Nginx upstream port: placeholder not substituted"
    FAILURES=$((FAILURES + 1))
fi
echo ""

echo "[5] Nginx Configuration"
echo "-----------------------------------"
check_file "/etc/nginx/sites-available/nexus" "Nginx Nexus config"

if [ -L /etc/nginx/sites-enabled/nexus ]; then
    echo "✓ Nginx Nexus site: Enabled"
else
    echo "✗ Nginx Nexus site: Not enabled"
    FAILURES=$((FAILURES + 1))
fi

if [ ! -f /etc/nginx/sites-enabled/default ]; then
    echo "✓ Nginx default site: Removed"
else
    echo "⚠ Nginx default site: Still present"
fi

if nginx -t &>/dev/null; then
    echo "✓ Nginx configuration: Valid"
else
    echo "✗ Nginx configuration: Invalid"
    FAILURES=$((FAILURES + 1))
fi
echo ""

echo "[6] Systemd Services"
echo "-----------------------------------"
check_service "lab-init"
check_service "ssh"
check_service "nginx"
check_service "nexus"
echo ""

echo "[7] SSH Configuration"
echo "-----------------------------------"
check_file "/etc/ssh/sshd_config" "SSH daemon config"
check_file "/usr/sbin/sshd" "SSH daemon binary"

if sshd -t &>/dev/null; then
    echo "✓ SSH configuration: Valid"
else
    echo "⚠ SSH configuration: Cannot fully validate at build time (host keys absent)"
fi

if ls /etc/ssh/ssh_host_*_key 1>/dev/null 2>&1; then
    echo "✓ SSH host keys: Present"
else
    echo "⚠ SSH host keys: Not generated (will be created at boot by lab-init)"
fi
echo ""

echo "[8] User Configuration"
echo "-----------------------------------"
check_user "${INTERACTIVE_USER}"

if [ -f /etc/sudoers.d/nexus-user ]; then
    echo "✓ Sudo configuration for nexus daemon: Present"
else
    echo "⚠ Sudo configuration for nexus daemon: Not found"
fi

if [ -f "/etc/sudoers.d/${INTERACTIVE_USER}" ]; then
    echo "✓ Sudo configuration for ${INTERACTIVE_USER}: Present"
else
    echo "⚠ Sudo configuration for ${INTERACTIVE_USER}: Not found"
fi
echo ""

# ---------------------------------------------------------------------

echo "==============================="
if [ ${FAILURES} -eq 0 ]; then
    echo "✓ All health checks passed!"
else
    echo "✗ ${FAILURES} health check(s) failed"
fi
echo "==============================="

exit ${FAILURES}
