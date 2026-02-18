#!/usr/bin/env bash
# =======================================================================
# infra-bootstrap — Unified Bootstrap Orchestrator
# Categories included:
#   1) System Diagnostics & Preflight
#   2) Infrastructure Components Installer
# =======================================================================

set -Eeuo pipefail
IFS=$'\n\t'

# -----------------------------------------------------------------------
# Load Shared Library (colors, logging, hr(), banner(), item(), etc.)
# -----------------------------------------------------------------------
LIB_URL="https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/lib/common.sh"

TMP_LIB=$(mktemp)
curl -fsSL "$LIB_URL" -o "$TMP_LIB"
# shellcheck source=/dev/null
source "$TMP_LIB"
rm -f "$TMP_LIB"

banner "Infra-Bootstrap Orchestrator"

CHECKS_URL="https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/system-checks"
COMP_URL="https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/components"

# ======================================================================
# Helper to run remote scripts SAFELY (works with curl | sudo bash)
# ======================================================================
run_remote_sudo() {
    local url="$1"
    TMPF=$(mktemp)
    curl -fsSL "$url" -o "$TMPF"
    sudo bash "$TMPF"
    rm -f "$TMPF"
}

run_remote_local() {
    local url="$1"
    TMPF=$(mktemp)
    curl -fsSL "$url" -o "$TMPF"
    bash "$TMPF"
    rm -f "$TMPF"
}

safe_run_remote_sudo() {
    local url="$1"

    TMPF=$(mktemp)
    curl -fsSL "$url" -o "$TMPF"

    # Run safely — capture failure but DO NOT exit orchestrator
    if ! sudo bash "$TMPF"; then
        warn "Component failed — returning to menu."
    else
        ok "Execution completed."
    fi

    rm -f "$TMPF"
    blank
}

# ======================================================================
# INITIAL PREFLIGHT CHECK
# ======================================================================
section "Running initial preflight..."

TMP_PRE=$(mktemp)
curl -fsSL "$CHECKS_URL/preflight.sh" -o "$TMP_PRE"

if sudo bash "$TMP_PRE" >/dev/null 2>&1; then
    ok "Preflight passed."
else
    error "System preflight failed — cannot continue."
fi
rm -f "$TMP_PRE"
blank

# ======================================================================
# MAIN MENU LOOP
# ======================================================================
while true; do

    hr
    printf "%bMain Categories%b\n" "$C_BOLD" "$C_RESET"
    echo
    echo "  1) System Diagnostics & Preflight"
    echo "  2) Infrastructure Components Installer"
    echo "  0) Exit"
    echo

    read -rp "Select a category: " CHOICE < /dev/tty
    echo

    case "$CHOICE" in

# ======================================================================
# CATEGORY 1 — SYSTEM DIAGNOSTICS
# ======================================================================
        1)
            while true; do
                hr
                printf "%bSystem Diagnostics & Preflight%b\n" "$C_BOLD" "$C_RESET"
                echo
                echo "  1) Run Preflight Check"
                echo "  2) Show System Information"
                echo "  3) Show Installed Tool Versions"
                echo "  0) Back"
                echo

                read -rp "Choose an option: " S1 < /dev/tty
                echo

                case "$S1" in
                    1)
                        info "Running preflight..."
                        TMP_PRE=$(mktemp)
                        curl -fsSL "$CHECKS_URL/preflight.sh" -o "$TMP_PRE"
                        sudo bash "$TMP_PRE"
                        rm -f "$TMP_PRE"
                        ;;
                    2)
                        info "Gathering system info..."
                        run_remote_sudo "$CHECKS_URL/sys-info.sh"
                        ;;
                    3)
                        info "Collecting version list..."
                        run_remote_sudo "$CHECKS_URL/version-check.sh"
                        ;;
                    0)
                        break
                        ;;
                    *)
                        warn "Invalid choice"
                        ;;
                esac
            done
            ;;

# ======================================================================
# CATEGORY 2 — COMPONENTS INSTALLER
# ======================================================================
        2)
            while true; do
                hr
                printf "%bInfrastructure Components Installer%b\n" "$C_BOLD" "$C_RESET"
                echo
                echo "  1) Docker"
                echo "  2) Kubernetes CLI (kubectl/helm/kustomize/k9s)"
                echo "  3) kind"
                echo "  4) Terraform"
                echo "  5) Ansible"
                echo "  6) AWS + EKS Toolkit"
                echo "  7) Trivy Security Scanner"
                echo "  8) Jenkins (Cloud/VM setups)"
                echo "  0) Back"
                echo

                read -rp "Choose a tool to install: " S2 < /dev/tty
                echo

                case "$S2" in
                    1) safe_run_remote_sudo "$COMP_URL/docker-setup.sh" ;;
                    2) safe_run_remote_sudo "$COMP_URL/kubernetes-cli.sh" ;;
                    3) safe_run_remote_sudo "$COMP_URL/kind-setup.sh" ;;
                    4) safe_run_remote_sudo "$COMP_URL/terraform-setup.sh" ;;
                    5) safe_run_remote_sudo "$COMP_URL/ansible-setup.sh" ;;
                    6) safe_run_remote_sudo "$COMP_URL/aws-eks-stack.sh" ;;
                    7) safe_run_remote_sudo "$COMP_URL/trivy-setup.sh" ;;
                    8) safe_run_remote_sudo "$COMP_URL/jenkins-setup.sh" ;;
                    0) break ;;
                    *) warn "Invalid selection" ;;
                esac
            done
            ;;

# ======================================================================
# EXIT SCRIPT
# ======================================================================
        0)
            hr
            ok "Exiting orchestrator — goodbye."
            exit 0
            ;;

        *)
            warn "Invalid option"
            ;;
    esac

done
