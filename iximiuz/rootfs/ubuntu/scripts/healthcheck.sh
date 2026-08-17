#!/bin/bash
set -euo pipefail

#######################################################################
# healthcheck.sh
#
# Build-time health checks for the Ubuntu 24.04 base rootfs image.
# Every other image in this repo inherits from this one, so a
# regression here breaks all of them at boot with no build signal.
#
# NOTE: Runs at BUILD TIME inside Docker.
#   - systemd is NOT running during build
#   - Services are verified via systemd symlinks, not systemctl
#   - /.dockerenv is deliberately NOT checked: the runtime recreates
#     it, so nothing inside the build can tell the truth about it
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

pass() { echo "✓ $1"; }
fail() { echo "✗ $1"; FAILURES=$((FAILURES + 1)); }

echo "==============================="
echo "Running Health Checks (base)"
echo "==============================="
echo ""

# --- Requirement: an init system -------------------------------------
[ -x /lib/systemd/systemd ] \
    && pass "systemd present at /lib/systemd/systemd" \
    || fail "systemd missing at /lib/systemd/systemd"

# --- Requirement: sshd reachable at boot -----------------------------
[ -x /usr/sbin/sshd ] \
    && pass "sshd binary present" \
    || fail "sshd binary missing"

[ -e /etc/systemd/system/multi-user.target.wants/ssh.service ] \
    && pass "ssh.service enabled at boot" \
    || fail "ssh.service NOT enabled at boot, or symlink dangling"

[ ! -e /etc/systemd/system/sockets.target.wants/ssh.socket ] \
    && pass "ssh.socket disabled" \
    || fail "ssh.socket still enabled and will shadow ssh.service"

# --- Requirement: no baked-in per-machine identity -------------------
# machine-id is written as a single newline, so it is 1 byte, not 0.
# systemd treats whitespace-only as unset, so test content, not size.
for f in /etc/machine-id /var/lib/dbus/machine-id; do
    if [ -f "$f" ] && [ -z "$(tr -d '[:space:]' < "$f")" ]; then
        pass "$f present and unset"
    else
        fail "$f missing or populated"
    fi
done

if ls /etc/ssh/ssh_host_* >/dev/null 2>&1; then
    fail "SSH host keys baked into the image"
else
    pass "no SSH host keys in image"
fi

# --- Requirement: the interactive user already exists ----------------
id "${INTERACTIVE_USER}" >/dev/null 2>&1 \
    && pass "user ${INTERACTIVE_USER} exists" \
    || fail "user ${INTERACTIVE_USER} missing"

# --- Platform contract: examiner unit declared and enabled -----------
# The platform supplies the examiner binary at boot; the unit is
# pre-declared here so systemd can start it once the binary lands.
# Removing either the unit file or its enable symlink silently breaks
# init task reporting on every image built from this base.
[ -f /etc/systemd/system/examiner.service ] \
    && pass "examiner.service unit file present" \
    || fail "examiner.service unit file missing"

[ -e /etc/systemd/system/multi-user.target.wants/examiner.service ] \
    && pass "examiner.service enabled and symlink resolves" \
    || fail "examiner.service not enabled, or symlink dangling"

echo ""
echo "==============================="
if [ ${FAILURES} -eq 0 ]; then
    echo "✓ All base health checks passed"
else
    echo "✗ ${FAILURES} health check(s) failed"
fi
echo "==============================="

exit ${FAILURES}
