#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

# ───────────────────────── Parse DRY RUN flag ───────────────────────────────
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --dry-run)
      DRY_RUN=1
      ;;
  esac
done

export DRY_RUN

# ───────────────────────── Load common library (bootstrap) ──────────────────
LIB_URL="https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/lib/common.sh"

TMP_LIB="$(mktemp -t infra-bootstrap-XXXXXXXX.sh)"
curl -fsSL "$LIB_URL" -o "$TMP_LIB" || {
  echo "FATAL: Unable to download common.sh from $LIB_URL"
  exit 1
}

source "$TMP_LIB" || {
  echo "FATAL: Unable to source common.sh"
  rm -f "$TMP_LIB"
  exit 1
}

rm -f "$TMP_LIB"

# ───────────────────────── Root requirement ─────────────────────────────────
require_root

info "System Preflight Checks"

# ===================== 1. OS Compatibility ======================
if [[ ! -f /etc/os-release ]]; then
  error "/etc/os-release not found – cannot determine OS."
fi

# shellcheck source=/dev/null
source /etc/os-release

case "${ID,,}" in
  ubuntu|linuxmint|pop)
    ok "Supported OS detected: ${PRETTY_NAME:-$ID}"
    blank
    ;;
  *)
    error "Unsupported OS: ${PRETTY_NAME:-$ID}. This project supports Ubuntu-based distributions only (e.g. Ubuntu, Linux Mint, Pop!_OS)."
    ;;
esac

# ===================== 2. Required Commands =====================
required_cmds=(bash lsb_release wget unzip ping)
missing=()
packages=()

# Detect missing or broken commands
for cmd in "${required_cmds[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1 || ! "$cmd" --version >/dev/null 2>&1; then
    missing+=("$cmd")
  fi
done

# Map commands → installable apt package names
for cmd in "${missing[@]}"; do
  case "$cmd" in
    lsb_release) packages+=("lsb-release") ;;  # special fix
    ping)        packages+=("iputils-ping") ;; # special fix
    *) packages+=("$cmd") ;;
  esac
done

if (( ${#missing[@]} > 0 )); then
  warn "Missing core utilities: $(IFS=,; echo "${missing[*]}")"   
  blank
  require_cmd apt-get
  info "Installing required utilities (noninteractive mode)..."

  # Clean controlled output instead of raw apt warning
  if apt-get update -qq >/dev/null 2>&1 \
     && apt-get install -yqq "${packages[@]}" >/dev/null 2>&1; then
      ok "Core utilities installed successfully."
      blank
  else
      error "Failed to install required utilities. Check apt sources or network."
  fi
else
  ok "Core shell utilities are present."
  blank
fi

# ===================== 3. Internet + DNS ========================
info "Checking basic Internet connectivity (ICMP)..."
if ping -c1 -W3 8.8.8.8 >/dev/null 2>&1; then
  ok "Internet connectivity verified (ping to 8.8.8.8)."
  blank
else
  error "No network connectivity – cannot reach 8.8.8.8. Connect to the internet and retry."
fi

info "Checking DNS & HTTPS reachability..."
if curl -fsSL https://github.com >/dev/null 2>&1; then
  ok "DNS resolution and HTTPS access working (github.com)."
  blank
else
  warn "DNS/HTTPS check failed – remote downloads may fail (github.com unreachable)."
  blank
fi

# ===================== 4. Architecture ==========================
arch=$(uname -m)
case "$arch" in
  x86_64|amd64)
    ok "Architecture supported: $arch"
    blank
    ;;
  *)
    error "Unsupported architecture: $arch. This project supports x86_64 / amd64 only."
    ;;
esac

# ===================== 5. CPU / RAM / Disk ======================
cpus=$(nproc || echo 1)
ram_mb=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo)
disk_gb=$(df -Pm / | awk 'NR==2{print int($4/1024)}')

info "Evaluating hardware capacity..."
(( cpus < 2 )) && warn "Low CPU cores: ${cpus}. Recommended: ≥ 2 for lab workloads."
(( ram_mb < 2000 )) && warn "Low RAM: ${ram_mb}MB. Recommended: ≥ 2048MB."
(( disk_gb < 10 )) && warn "Low disk space: ${disk_gb}GB free on /. Recommended: ≥ 10GB."

ok "Hardware checks completed."
blank

# ===================== 6. Virtualization Support =================
info "Checking CPU virtualization support flags..."
if grep -Eq 'vmx|svm' /proc/cpuinfo; then
  ok "Virtualization extensions detected (vmx/svm)."
  blank
else
  warn "No virtualization flags detected (vmx/svm). Some tooling (VM-based labs) may be limited."
  blank
fi

# ===================== 7. Systemd Availability ===================
info "Checking init system (systemd)..."
if command -v systemctl >/dev/null 2>&1; then
  ok "systemd is available – service-based components can be managed."
  blank
else
  warn "systemd not found. Some services may not be controllable via systemctl."
  blank
fi

# ===================== Final Summary =============================
ok "Preflight checks completed successfully."
info "Your system is ready to run infra-bootstrap scripts."
blank

exit 0