#!/usr/bin/env bash
# =====================================================================
# infra-bootstrap — System Information & Diagnostic Report
#
# PURPOSE:
#   • Run universal preflight first
#   • Display system / network / hardware inventory
#   • Detect virtualization & cloud environment safely
#   • Optional hostname change before K8s bootstrap
#   • No Kubernetes logic — this script is universal
#
# STYLE:
#   • UI formatting matches version-check + common.sh
#   • Uses section(), banner(), footer(), hr() from common.sh
# =====================================================================

set -Eeuo pipefail
IFS=$'\n\t'

# ================= Load Shared Library =================
COMMON_URL="https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/lib/common.sh"
tmp="$(mktemp)"
curl -fsSL "$COMMON_URL" -o "$tmp" || { echo "common.sh missing"; exit 1; }
source "$tmp"
rm -f "$tmp"


banner "System Information & Diagnostics"


# ===================== Preflight ======================
section "Running preflight checks..."
PRE_URL="https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/system-checks/preflight.sh"

if ! out=$(bash <(curl -fsSL "$PRE_URL") 2>&1); then
    error "Preflight failed — aborting system diagnostic."
    printf "\nDetails:\n%s\n" "$out"
    exit 1
fi
ok "Preflight passed."
blank



# ================= Core System Identity =================
section "Core System Identity"
printf " %b%-22s%b %s\n" "$C_CYAN" "Hostname:" "$C_RESET" "$(hostname)"
printf " %b%-22s%b %s\n" "$C_CYAN" "OS:" "$C_RESET" "$(lsb_release -ds)"
printf " %b%-22s%b %s\n" "$C_CYAN" "Kernel:" "$C_RESET" "$(uname -r)"
printf " %b%-22s%b %s\n" "$C_CYAN" "Machine UUID:" "$C_RESET" "$(cat /etc/machine-id)"
printf " %b%-22s%b %s\n" "$C_CYAN" "Uptime:" "$C_RESET" "$(uptime -p)"
blank


# ================= Hostname Rename Prompt =================
if [[ "${1:-}" != "--no-hostname" ]]; then
    read -rp "Change hostname? (Enter new hostname or press Enter to skip): " NEW_HOSTNAME < /dev/tty
    if [[ -n "$NEW_HOSTNAME" ]]; then
        printf "\nUpdating hostname to %s...\n" "$NEW_HOSTNAME"
        hostnamectl set-hostname "$NEW_HOSTNAME"
        ok "Hostname updated — reboot recommended."
        blank
    fi
fi



# ======================= Hardware Info =======================
section "Hardware"
printf " %b%-22s%b %s\n" "$C_CYAN" "CPU Model:" "$C_RESET" "$(lscpu | awk -F: '/Model name/ {print $2}' | xargs)"
printf " %b%-22s%b %s cores\n" "$C_CYAN" "CPU Cores:" "$C_RESET" "$(nproc)"
printf " %b%-22s%b %s\n" "$C_CYAN" "Memory:" "$C_RESET" "$(free -h | awk '/Mem/ {print $2}')"
printf " %b%-22s%b %s used / %s total\n" "$C_CYAN" "Disk Usage:" "$C_RESET" \
    "$(df -h --total | awk '/total/ {print $3}')" "$(df -h --total | awk '/total/ {print $2}')"
blank



# ====================== Networking ======================
section "Networking"
printf " %b%-22s%b %s\n" "$C_CYAN" "Private IP:" "$C_RESET" "$(hostname -I | awk '{print $1}')"
printf " %b%-22s%b %s\n" "$C_CYAN" "Public IP:" "$C_RESET" "$(curl -s --max-time 3 ifconfig.me || echo 'Unavailable')"
printf " %b%-22s%b %s\n" "$C_CYAN" "DNS Servers:" "$C_RESET" \
    "$(awk '/nameserver/ {print $2}' /etc/resolv.conf | paste -sd ', ')"
printf " %b%-22s%b %s\n" "$C_CYAN" "Default Gateway:" "$C_RESET" "$(ip route | awk '/default/ {print $3}')"
blank

section "Virtualization / Platform"

# --- virtualization detection (final hardened) ---
virt_raw="$(systemd-detect-virt 2>/dev/null || true)"
virt_raw="$(echo "$virt_raw" | head -n1 | tr -d '[:space:]')"

case "$virt_raw" in
    ""|none|noneunknown|unknown)
        virt="Bare-metal (No Hypervisor)"
        ;;
    container)
        virt="Container / Namespaced Runtime"
        ;;
    kvm|qemu|vmware|oracle|microsoft|hyperv|xen|wsl)
        virt="Virtual Machine ($virt_raw)"
        ;;
    *)
        virt="Unknown / Unreported ($virt_raw)"
        ;;
esac

printf " %b%-22s%b %s\n" "$C_CYAN" "Virtualization:" "$C_RESET" "$virt"
blank


# --- Cloud Detection w/ Silence & No Leak ---
detect_cloud() {
    curl -fs --max-time 1 http://169.254.169.254/latest/meta-data/instance-id   >/dev/null 2>&1 && echo "AWS"      && return
    curl -fs --max-time 1 -H 'Metadata-Flavor: Google' \
         http://169.254.169.254/computeMetadata/v1/instance/id                >/dev/null 2>&1 && echo "GCP"      && return
    curl -fs --max-time 1 http://169.254.169.254/metadata/instance?api-version=2021-02-01 \
                                                                              >/dev/null 2>&1 && echo "Azure"    && return
    curl -fs --max-time 1 http://169.254.169.254/openstack/latest/meta_data.json >/dev/null 2>&1 && echo "OpenStack" && return
}

cloud="$(detect_cloud || true)"
[[ -z "$cloud" ]] && cloud="Unknown / Bare-metal / VM"

printf " %b%-22s%b %s\n" "$C_CYAN" "Cloud Provider:" "$C_RESET" "$cloud"
blank



# ================= Health / Reboot Notice =================
section "System Health"
[[ -f /var/run/reboot-required ]] && warn "Reboot required to apply updates." \
                                  || ok "No reboot pending."
blank



footer "System diagnostic complete"