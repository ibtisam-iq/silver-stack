#!/bin/bash
set -euo pipefail

#######################################################################
# healthcheck.sh
#
# Performs build-time health checks on the Jenkins rootfs image to
# ensure all components are properly installed and configured.
#
# NOTE: Runs at BUILD TIME inside Docker.
#   - systemd is NOT running during build
#   - Services are verified via systemd symlinks, not systemctl
#   - Packages are checked via dpkg-query
#
# Arguments:
#   USER - Interactive user to verify (default: current user)
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
    local cmd="${1}"
    local name="${2:-${cmd}}"

    if command -v "${cmd}" &> /dev/null; then
        echo "✓ ${name}: $("${cmd}" --version 2>&1 | head -n 1)"
        return 0
    else
        echo "✗ ${name}: Not found"
        FAILURES=$((FAILURES + 1))
        return 1
    fi
}

check_file() {
    local file="${1}"
    local name="${2:-${file}}"

    if [ -f "${file}" ]; then
        echo "✓ File exists: ${name}"
        return 0
    else
        echo "✗ File missing: ${name}"
        FAILURES=$((FAILURES + 1))
        return 1
    fi
}

check_directory() {
    local dir="${1}"
    local name="${2:-${dir}}"

    if [ -d "${dir}" ]; then
        echo "✓ Directory exists: ${name}"
        return 0
    else
        echo "✗ Directory missing: ${name}"
        FAILURES=$((FAILURES + 1))
        return 1
    fi
}

check_service() {
    local service="${1}"
    local wants_link="/etc/systemd/system/multi-user.target.wants/${service}.service"

    if [ -L "${wants_link}" ]; then
        echo "✓ Systemd service enabled: ${service}"
        return 0
    else
        echo "✗ Systemd service not enabled: ${service}"
        FAILURES=$((FAILURES + 1))
        return 1
    fi
}

check_user() {
    local username="${1}"

    if id "${username}" &>/dev/null; then
        echo "✓ User exists: ${username} (UID: $(id -u "${username}"))"
        return 0
    else
        echo "⚠ User not found: ${username} (will be created at runtime)"
        return 0
    fi
}

check_package() {
    local pkg="${1}"
    local name="${2:-${pkg}}"

    if dpkg-query -W -f='${Status}' "${pkg}" 2>/dev/null | grep -q "install ok installed"; then
        local version
        version=$(dpkg-query -W -f='${Version}' "${pkg}" 2>/dev/null)
        echo "✓ ${name} package: Installed (${version})"
        return 0
    else
        echo "✗ ${name} package: Not installed"
        FAILURES=$((FAILURES + 1))
        return 1
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

echo "[3] Jenkins Installation"
echo "-----------------------------------"
check_package "jenkins" "Jenkins"
check_directory "/var/lib/jenkins" "Jenkins home"
check_directory "/var/lib/jenkins/plugins" "Jenkins plugins directory"
check_user "jenkins"
echo ""

echo "[4] Nginx Configuration"
echo "-----------------------------------"
check_file "/etc/nginx/sites-available/jenkins" "Nginx Jenkins config"

if [ -L /etc/nginx/sites-enabled/jenkins ]; then
    echo "✓ Nginx Jenkins site: Enabled"
else
    echo "✗ Nginx Jenkins site: Not enabled"
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

echo "[5] Systemd Services"
echo "-----------------------------------"
check_service "lab-init"
check_service "ssh"
check_service "nginx"
check_service "jenkins"
echo ""

echo "[6] SSH Configuration"
echo "-----------------------------------"
check_file "/etc/ssh/sshd_config" "SSH daemon config"
check_file "/usr/sbin/sshd" "SSH daemon binary"

if sshd -t &>/dev/null; then
    echo "✓ SSH configuration: Valid"
else
    echo "⚠ SSH configuration: Cannot fully validate at build time (host keys absentst)"
    # FAILURES=$((FAILURES + 1))
fi

if ls /etc/ssh/ssh_host_*_key 1>/dev/null 2>&1; then
    echo "✓ SSH host keys: Present"
else
    echo "⚠ SSH host keys: Not generated (will be created at boot by lab-init)"
fi
echo ""

echo "[7] User Configuration"
echo "-----------------------------------"
check_user "${INTERACTIVE_USER}"

if [ -f /etc/sudoers.d/jenkins-user ]; then
    echo "✓ Sudo configuration for jenkins daemon: Present"
else
    echo "⚠ Sudo configuration for jenkins daemon: Not found"
fi

if [ -f "/etc/sudoers.d/${INTERACTIVE_USER}" ]; then
    echo "✓ Sudo configuration for ${INTERACTIVE_USER}: Present"
else
    echo "⚠ Sudo configuration for ${INTERACTIVE_USER}: Not found"
fi
echo ""

echo "[8] File Permissions"
echo "-----------------------------------"
if [ -d /var/lib/jenkins ]; then
    JENKINS_OWNER=$(stat -c '%U' /var/lib/jenkins)
    if [ "${JENKINS_OWNER}" = "jenkins" ]; then
        echo "✓ Jenkins home ownership: Correct (jenkins)"
    else
        echo "✗ Jenkins home ownership: Incorrect (${JENKINS_OWNER})"
        FAILURES=$((FAILURES + 1))
    fi
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
