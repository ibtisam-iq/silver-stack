#!/usr/bin/env bash
# =====================================================================
# infra-bootstrap — Component Installer: Ansible
# Author: Muhammad Ibtisam Iqbal
# License: MIT
# =====================================================================

set -Eeuo pipefail
IFS=$'\n\t'


# ================= Load Core Library =================
COMMON_URL="https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/lib/common.sh"
tmp="$(mktemp)"
curl -fsSL "$COMMON_URL" -o "$tmp" || { echo "common.sh fetch failed"; exit 1; }
source "$tmp"
rm -f "$tmp"

banner "Installing: Ansible"


# ================= Preflight =================
section "Running preflight checks..."
PRE_URL="https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/system-checks/preflight.sh"

if ! bash <(curl -fsSL "$PRE_URL") >/dev/null 2>&1; then
    error "Preflight failed — aborting Ansible installation"
fi
ok "Preflight passed."
blank


# ================= Existing Install Detector =================
is_installed() {
    command -v ansible >/dev/null 2>&1 || \
    python3 - <<'EOF' >/dev/null 2>&1
import ansible
EOF
}

if is_installed; then
    version="$(ansible --version 2>/dev/null | head -n1 | awk '{print $NF}' | tr -d '[]')"
    warn "Ansible already installed — skipping installation"
    printf " Installed Version: %s\n" "${version:-Unknown}"
    footer "Install skipped"
    exit 0
fi


# ================= Install =================
section "Installing Ansible dependencies..."
apt-get update -qq
apt-get install -y software-properties-common >/dev/null 2>&1 || error "Dependency install failed"
ok "Dependencies ready."
blank


section "Adding Ansible repository..."
if add-apt-repository --yes --update ppa:ansible/ansible >/dev/null 2>&1; then
    ok "Repository added."
else
    error "Failed to add Ansible PPA"
fi
blank


section "Installing Ansible package..."
if apt-get update -qq && apt-get install -y ansible >/dev/null 2>&1; then
    ok "Ansible installed successfully."
else
    error "apt install failed — install incomplete"
fi
blank


# ================= Post-Install Verification =================
if ! is_installed; then
    error "Post-install check failed — ansible not present in PATH or python packages"
fi

version="$(ansible --version 2>/dev/null | head -n1 | awk '{print $NF}' | tr -d '[]')"
printf " Installed Version: %s\n" "${version:-Unknown}"


footer "Ansible setup completed successfully"
# exit 0 (optional)