#!/usr/bin/env bash
# ============================================================================
# infra-bootstrap — Kind Installer (Linux amd64)
# ============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

# ─────────────────────── Load shared library ────────────────────────────────
LIB_URL="https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/lib/common.sh"
source <(curl -fsSL "$LIB_URL") || { echo "FATAL: Unable to load core library"; exit 1; }

banner "Installing: Kind"


# ───────────────────────────── Preflight ─────────────────────────────────────
info "Running preflight..."
if bash <(curl -fsSL "https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/system-checks/preflight.sh") >/dev/null 2>&1; then
    ok "Preflight passed."
else
    error "Preflight failed — aborting."
fi
blank


# ─────────────────────── Check if already installed ──────────────────────────
if command -v kind >/dev/null 2>&1; then
    CURRENT=$(kind version 2>/dev/null | sed -n 's/^kind v//p' | awk '{print $1}')
    warn "Kind already installed ($CURRENT)"
    hr
    item "Kind" "$CURRENT"
    hr
    ok "No installation performed"
    blank
    exit 0
fi

# ─────────────────────────── Install Trivy ───────────────────────────────────

section "Installing Kind"

[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.30.0/kind-$(uname)-amd64 > /dev/null 2>&1
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

ok "Kind installed successfully"
blank

# ───────────────────────────── Version Summary ───────────────────────────────
PAD=16
item_ver() { printf " %b•%b %-*s %s\n" "$C_CYAN" "$C_RESET" "$PAD" "$1:" "$2"; }

KIND_VERSION=$(kind version 2>/dev/null | sed -n 's/^kind v//p' | awk '{print $1}')

hr
item_ver "Kind" "${TRIVY_VERSION:-unknown}"
hr
footer "Kind installation complete."

exit 0
