#!/usr/bin/env bash
# ============================================================================
# infra-bootstrap — Terraform Installer (Linux amd64)
# Installs latest stable Terraform using HashiCorp releases
# ============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

# ───────────────────────── Load shared library ───────────────────────────────
LIB_URL="https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/lib/common.sh"
source <(curl -fsSL "$LIB_URL") || { echo "FATAL: Unable to load core library"; exit 1; }

banner "Installing: Terraform"


# ───────────────────────────── Preflight ─────────────────────────────────────
info "Running preflight..."
if bash <(curl -fsSL "https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/system-checks/preflight.sh") >/dev/null 2>&1; then
    ok "Preflight passed."
else
    error "Preflight failed — aborting."
fi
blank


# ─────────────────────── Check if already installed ──────────────────────────
if command -v terraform >/dev/null 2>&1; then
    CURRENT=$(terraform version 2>/dev/null | head -n1 | awk '{print $2}' | sed 's/^v//')
    warn "Terraform already installed ($CURRENT)"
    hr
    item "Terraform" "$CURRENT"
    hr
    ok "No installation performed"
    blank
    exit 0
fi


# ───────────────────────── Architecture check ────────────────────────────────
ARCH=$(uname -m)
if [[ "$ARCH" != "x86_64" && "$ARCH" != "amd64" ]]; then
    error "Terraform binary install supports x86_64 only — detected $ARCH"
fi


# ───────────────────────── Fetch latest Terraform version ─────────────────────
section "Resolving latest Terraform version"

# Try GitHub API first (best source)
LATEST=$(curl -fsSL https://api.github.com/repos/hashicorp/terraform/releases/latest 2>/dev/null \
    | grep '"tag_name"' | cut -d '"' -f4 | sed 's/^v//' || true)

# If GitHub fails or returned empty -> fallback to HashiCorp releases index
if [[ -z "$LATEST" ]]; then
    warn "GitHub API unavailable — falling back to HashiCorp releases index"

    LATEST=$(curl -fsSL https://releases.hashicorp.com/terraform/ \
        | grep -Eo 'terraform/[0-9]+\.[0-9]+\.[0-9]+' \
        | cut -d/ -f2 \
        | sort -Vr \
        | head -n 1)
fi

[[ -n "${LATEST:-}" ]] || error "Failed to detect latest Terraform version"

ok "Latest version: $LATEST"
blank


# ─────────────────────────── Install Terraform ───────────────────────────────
section "Installing Terraform"

DOWNLOAD_URL="https://releases.hashicorp.com/terraform/${LATEST}/terraform_${LATEST}_linux_amd64.zip"

info "Downloading Terraform..."
curl -fsSL -o terraform.zip "$DOWNLOAD_URL" || error "Failed to download Terraform"

# Ensure unzip exists (Ubuntu-only, silent)
if ! command -v unzip >/dev/null 2>&1; then
    info "Installing unzip..."

    sudo apt-get update -y -qq >/dev/null 2>&1 || true
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq unzip >/dev/null 2>&1 \
        || error "Failed to install unzip"
fi

info "Extracting binary..."
unzip -oq terraform.zip || error "Failed to unzip"
rm -f terraform.zip

info "Installing to /usr/local/bin..."
chmod +x terraform
sudo mv terraform /usr/local/bin/terraform

ok "Terraform installed"
blank


# ───────────────────────────── Version Summary ───────────────────────────────
PAD=20
item_ver() { printf " %b•%b %-*s %s\n" "$C_CYAN" "$C_RESET" "$PAD" "$1:" "$2"; }

TERRAFORM_VERSION=$(terraform version 2>/dev/null | head -n1 | awk '{print $2}' | sed 's/^v//')

hr
item_ver "Terraform" "${TERRAFORM_VERSION:-unknown}"
hr
footer "Terraform setup completed successfully"

exit 0
