#!/usr/bin/env bash
# ============================================================================
# infra-bootstrap — Trivy Installer (Linux amd64)
# Installs latest stable Trivy release from GitHub (NOT hardcoded)
# ============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

# ─────────────────────── Load shared library ────────────────────────────────
LIB_URL="https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/lib/common.sh"
source <(curl -fsSL "$LIB_URL") || { echo "FATAL: Unable to load core library"; exit 1; }

banner "Installing: Trivy"


# ───────────────────────────── Preflight ─────────────────────────────────────
info "Running preflight..."
if bash <(curl -fsSL "https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/system-checks/preflight.sh") >/dev/null 2>&1; then
    ok "Preflight passed."
else
    error "Preflight failed — aborting."
fi
blank


# ─────────────────────── Check if already installed ──────────────────────────
if command -v trivy >/dev/null 2>&1; then
    CURRENT=$(trivy --version 2>/dev/null | head -n1 | awk '{print $2}' | sed 's/^v//')
    warn "Trivy already installed ($CURRENT)"
    hr
    item "Trivy" "$CURRENT"
    hr
    ok "No installation performed"
    blank
    exit 0
fi

# ─────────────────────────── Install Trivy ───────────────────────────────────

section "Installing Trivy (via official installer)"

TRIVY_VERSION=""     # leave empty to install latest

INSTALLER_URL="https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh"

if [[ -n "$TRIVY_VERSION" ]]; then
    # Install specific version
    curl -fsSL "$INSTALLER_URL" \
        | sudo sh -s -- -b /usr/local/bin "v${TRIVY_VERSION}" >/dev/null 2>&1 \
        || error "Failed to install Trivy (version ${TRIVY_VERSION})"
else
    # Install latest version silently
    curl -fsSL "$INSTALLER_URL" \
        | sudo sh -s -- -b /usr/local/bin >/dev/null 2>&1 \
        || error "Failed to install Trivy"
fi

ok "Trivy installed successfully"
blank

# ───────────────────────────── Version Summary ───────────────────────────────
PAD=16
item_ver() { printf " %b•%b %-*s %s\n" "$C_CYAN" "$C_RESET" "$PAD" "$1:" "$2"; }

TRIVY_VERSION=$(trivy --version 2>/dev/null | head -n1 | awk '{print $2}' | sed 's/^v//')

hr
item_ver "Trivy" "${TRIVY_VERSION:-unknown}"
hr
footer "Trivy installation complete."

exit 0
