#!/usr/bin/env bash
# ============================================================================
# infra-bootstrap — Kubernetes Cluster Configuration
# ============================================================================
# NOTE:
# • Sourced via curl | sudo bash
# • Uses common.sh and preflight exactly like other scripts
# ============================================================================

set -euo pipefail
IFS=$'\n\t'
# ───────────────────────── Load shared library ───────────────────────────────
LIB_URL="https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/lib/common.sh"
source <(curl -fsSL "$LIB_URL") || { echo "FATAL: cannot load common library"; exit 1; }

banner "Kubernetes — Prepare Node"
require_root

# ───────────────────────── Defaults ─────────────────────────────────────────
DEFAULT_K8S_VERSION="1.34"
DEFAULT_POD_CIDR="10.244.0.0"
SUPPORTED_K8S_VERSIONS=("1.29" "1.30" "1.31" "1.32" "1.33" "1.34")

# ───────────────────────── Helpers ──────────────────────────────────────────
detect_control_plane_ip() {
  ip route get 8.8.8.8 2>/dev/null | awk '{print $7; exit}'
}

validate_k8s_version() {
  local v="$1"
  for allowed in "${SUPPORTED_K8S_VERSIONS[@]}"; do
    [[ "$v" == "$allowed" ]] && return 0
  done
  return 1
}

validate_hostname() {
  [[ "$1" =~ ^[a-zA-Z0-9][-a-zA-Z0-9]{0,62}$ ]]
}

validate_cidr() {
  [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]
}

# ───────────────────────── Control Plane IP (NO INPUT) ──────────────────────
CONTROL_PLANE_IP="$(detect_control_plane_ip)"
info "Detected Control Plane IP: $CONTROL_PLANE_IP"
blank
# ───────────────────────── Kubernetes Version Selection ─────────────────────
# ───────────────────────── Kubernetes Version Selection ─────────────────────
DEFAULT_K8S_VERSION="1.34"
SUPPORTED_K8S_VERSIONS=("1.29" "1.30" "1.31" "1.32" "1.33" "1.34")
SUPPORTED_K8S_VERSIONS_STR="${SUPPORTED_K8S_VERSIONS[*]}"

# Detect installed kubelet version (Major.Minor only)
INSTALLED_MM=""
if command -v kubelet >/dev/null 2>&1; then
  INSTALLED_MM="$(kubelet --version | awk '{print $2}' | sed 's/^v//' | cut -d. -f1,2 || echo "")"
  info "Detected installed kubelet version: $INSTALLED_MM"
fi

CURRENT_VERSION="${INSTALLED_MM:-$DEFAULT_K8S_VERSION}"

# Max allowed downgrade (one minor only)
MAX_DOWNGRADE_MM=""
if [[ -n "$INSTALLED_MM" ]]; then
  major="${INSTALLED_MM%%.*}"
  minor="${INSTALLED_MM#*.}"
  MAX_DOWNGRADE_MM="${major}.$((minor - 1))"
fi

K8S_VERSION=""
K8S_VERSION_ACTION="noop"

# Phase 1: Garbage / invalid format loop — 5 attempts → fallback to safe version
garbage_attempts=0
MAX_GARBAGE_ATTEMPTS=5

while (( garbage_attempts < MAX_GARBAGE_ATTEMPTS )); do
  info "Current Kubernetes version: $CURRENT_VERSION"
  info "Supported Kubernetes versions: $SUPPORTED_K8S_VERSIONS_STR"
  blank
  info "Press Enter to keep [$CURRENT_VERSION] (recommended)"
  info "Or type a supported Kubernetes version (Major.Minor format)"
  printf "› " > /dev/tty
  read -r user_input < /dev/tty || { warn "Read failed"; break; }
  blank

  # Empty → use current/default
  if [[ -z "$user_input" ]]; then
    K8S_VERSION="$CURRENT_VERSION"
    K8S_VERSION_ACTION="noop"
    break
  fi

  # Strip leading 'v'
  user_input="${user_input#v}"

  # Strict format check: exactly Major.Minor (e.g., 1.34)
  if ! [[ "$user_input" =~ ^[0-9]+\.[0-9]{1,2}$ ]]; then
    ((garbage_attempts++))
    warn "Invalid format '$user_input' — must be Major.Minor like 1.34 (attempt $garbage_attempts/$MAX_GARBAGE_ATTEMPTS)"
    continue
  fi

  # Must be in supported list
  if [[ ! " ${SUPPORTED_K8S_VERSIONS[*]} " =~ " $user_input " ]]; then
    ((garbage_attempts++))
    warn "Version '$user_input' is not supported (attempt $garbage_attempts/$MAX_GARBAGE_ATTEMPTS)"
    continue
  fi

  # Passed garbage check — accept temporarily
  K8S_VERSION="$user_input"
  break
done

# If garbage attempts exhausted → fallback
if (( garbage_attempts >= MAX_GARBAGE_ATTEMPTS )) && [[ -z "$K8S_VERSION" ]]; then
  warn "Too many invalid inputs. Falling back to safe version: $CURRENT_VERSION"
  K8S_VERSION="$CURRENT_VERSION"
  K8S_VERSION_ACTION="noop"
fi

info "Selected Kubernetes version: $K8S_VERSION (proceeding to safety check)"
blank

# Phase 2: Safety check — only one minor downgrade allowed
safe_attempts=0
MAX_SAFE_ATTEMPTS=5

while (( safe_attempts < MAX_SAFE_ATTEMPTS )); do
  # No existing install → any supported version is fine
  if [[ -z "$INSTALLED_MM" ]]; then
    K8S_VERSION_ACTION="install"
    break
  fi

  installed_minor="${INSTALLED_MM#*.}"
  target_minor="${K8S_VERSION#*.}"

  # Same version
  if [[ "$K8S_VERSION" == "$INSTALLED_MM" ]]; then
    K8S_VERSION_ACTION="noop"
    break
  fi

  # Upgrade allowed
  if (( target_minor > installed_minor )); then
    K8S_VERSION_ACTION="upgrade"
    break
  fi

  # One minor downgrade allowed
  if [[ "$K8S_VERSION" == "$MAX_DOWNGRADE_MM" ]]; then
    warn "One-minor downgrade accepted: $INSTALLED_MM → $K8S_VERSION"
    K8S_VERSION_ACTION="downgrade"
    break
  fi

  # Too far downgrade → reject
  ((safe_attempts++))
  warn "Unsupported downgrade requested (attempt $safe_attempts/$MAX_SAFE_ATTEMPTS)"
  warn "Installed: $INSTALLED_MM"
  warn "Requested: $K8S_VERSION"
  warn "Maximum allowed: $MAX_DOWNGRADE_MM (or same/higher)"
  blank
  info "Enter a valid version:"
  info "• Keep current: $INSTALLED_MM"
  info "• Upgrade to higher"
  info "• Downgrade only to: $MAX_DOWNGRADE_MM"
  printf "› " > /dev/tty
  read -r new_input < /dev/tty || { warn "Read failed"; continue; }
  blank

  new_input="${new_input#v}"

  if ! [[ "$new_input" =~ ^[0-9]+\.[0-9]{1,2}$ ]]; then
    warn "Invalid format"
    continue
  fi

  if [[ ! " ${SUPPORTED_K8S_VERSIONS[*]} " =~ " $new_input " ]]; then
    warn "Version not supported"
    continue
  fi

  K8S_VERSION="$new_input"
done

# Final failure: too many unsafe attempts
if (( safe_attempts >= MAX_SAFE_ATTEMPTS )); then
  error "Too many attempts to select an unsafe Kubernetes version."
  error "Only same version, upgrade, or one minor downgrade ($MAX_DOWNGRADE_MM) allowed."
  exit 1
fi

info "Final Kubernetes version: $K8S_VERSION"
info "Action required: $K8S_VERSION_ACTION"
blank

export K8S_VERSION
export K8S_VERSION_ACTION
# ───────────────────────── Hostname (STRICT) ────────────────────────────────
CURRENT_HOSTNAME="$(hostnamectl --static)"
info "Current hostname: $CURRENT_HOSTNAME"
blank
info "Press Enter to keep [$CURRENT_HOSTNAME] or type a new hostname"

printf "› " > /dev/tty
read -r input < /dev/tty || true

if [[ -z "$input" ]]; then
  NODE_NAME="$CURRENT_HOSTNAME"
else
  if validate_hostname "$input"; then
    hostnamectl set-hostname "$input"
    NODE_NAME="$input"
    ok "Hostname changed to: $NODE_NAME"
  else
    error "Invalid hostname format. Exiting."
    exit 1
  fi
fi

blank

# ───────────────────────── Pod CIDR ─────────────────────────────────────────
POD_CIDR="$DEFAULT_POD_CIDR"
for attempt in 1 2 3; do
  info "Default Pod CIDR is [$DEFAULT_POD_CIDR]"
  blank
  info "Press Enter to accept [$DEFAULT_POD_CIDR] or type a new CIDR"
  printf "› " > /dev/tty
  read -r input < /dev/tty


  if [[ -z "$input" ]]; then
    break
  fi

  if validate_cidr "$input"; then
    POD_CIDR="$input"
    break
  fi

  warn "Invalid CIDR (attempt $attempt of 3)"
done

info "Pod CIDR set to: $POD_CIDR"
blank

# ───────────────────────── Container Runtime Method ─────────────────────────
# ───────────────────────── Container Runtime Method ─────────────────────────
DEFAULT_CONTAINERD_METHOD="package"
MAX_ATTEMPTS=3
attempt=1

info "Container runtime: containerd"
blank

while true; do
  info "Select installation method:"
  info "  [1] Package-managed  — recommended (default)"
  info "  [2] Binary-managed   — advanced"
  blank
  info "Input instructions:"
  info "• Press Enter  → use default (Package-managed)"
  info "• Type 1       → Package-managed"
  info "• Type 2       → Binary-managed"
  info "• Type info    → explain the difference"
  blank

  printf "› " > /dev/tty
  read -r input < /dev/tty || true
  blank

  case "$input" in
    "" | "1")
      CONTAINERD_INSTALL_METHOD="package"
      break
      ;;
    "2")
      CONTAINERD_INSTALL_METHOD="binary"
      break
      ;;
    "info")
      info "Containerd installation methods — overview"
      blank
      info "Package-managed:"
      info "• Installed via official Docker APT repository"
      info "• containerd and runc managed by OS package manager"
      info "• Automatic security updates"
      info "• Industry-standard choice for most Kubernetes clusters"
      blank
      info "Binary-managed:"
      info "• Installed from upstream containerd GitHub releases"
      info "• Full control over runtime binaries and versions"
      info "• Manual updates and lifecycle management"
      info "• Intended for advanced or controlled environments"
      blank
      info "Review complete. Please select an option."
      attempt=1
      continue
      ;;
    *)
      warn "Invalid input. Expected: Enter, 1, 2, or info. (attempt $attempt of $MAX_ATTEMPTS)"
      ;;
  esac

  if (( attempt >= MAX_ATTEMPTS )); then
    warn "Maximum invalid attempts reached. Falling back to default."
    CONTAINERD_INSTALL_METHOD="$DEFAULT_CONTAINERD_METHOD"
    break
  fi

  ((attempt++))
done

info "Containerd installation method selected: $CONTAINERD_INSTALL_METHOD"
blank
# ───────────────────────── Final Summary ────────────────────────────────

#hr
ok "Cluster configuration completed"
blank

# ───────────────────────── Export Contract ──────────────────────────────────
export CONTROL_PLANE_IP
#export K8S_VERSION
export NODE_NAME
export POD_CIDR
export CONTAINERD_INSTALL_METHOD
export K8S_VERSION_ACTION


