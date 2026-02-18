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

bash "$TMP_LIB" || {
  echo "FATAL: Unable to source common.sh"
  rm -f "$TMP_LIB"
  exit 1
}

rm -f "$TMP_LIB"

# ───────────────────────── Root requirement ─────────────────────────────────
require_root

# ───────────────────────── Defaults ─────────────────────────────────────────
DEFAULT_K8S_VERSION="1.35"
DEFAULT_POD_CIDR="10.244.0.0/16"
SUPPORTED_K8S_VERSIONS=("1.29" "1.30" "1.31" "1.32" "1.33" "1.34" "1.35")

# ───────────────────────── Helpers ──────────────────────────────────────────
detect_node_ip() {
  ip route get 8.8.8.8 2>/dev/null | awk '{print $7; exit}'
}

validate_k8s_version() {
  local v="$1"
  for allowed in "${SUPPORTED_K8S_VERSIONS[@]}"; do
    [[ "$v" == "$allowed" ]] && return 0
  done
  return 1
}

validate_cidr() {
  [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[12][0-9]|3[0-2])$ ]]
}

validate_cidr() {
  [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]
}

# ───────────────────────── Control Plane IP (NO INPUT) ──────────────────────
CONTROL_PLANE_IP="$(detect_node_ip)"
info "Detected NODE IP: $CONTROL_PLANE_IP"
blank

# ───────────────────────── Kubernetes Version ───────────────────────────────
K8S_VERSION="$DEFAULT_K8S_VERSION"
SUPPORTED_K8S_VERSIONS_STR="$(printf "%s " "${SUPPORTED_K8S_VERSIONS[@]}")"
SUPPORTED_K8S_VERSIONS_STR="${SUPPORTED_K8S_VERSIONS_STR%% }"

for attempt in 1 2 3; do
  info "Supported Kubernetes versions: $SUPPORTED_K8S_VERSIONS_STR"
  blank
  info "Default Kubernetes version is [$DEFAULT_K8S_VERSION]"
  blank
  info "Press Enter to accept [$DEFAULT_K8S_VERSION] or type a new version"
  printf "› " > /dev/tty
  read -r input < /dev/tty


  if [[ -z "$input" ]]; then
    break
  fi

  if validate_k8s_version "$input"; then
    K8S_VERSION="$input"
    break
  fi

  warn "Invalid Kubernetes version (attempt $attempt of 3)"
done

info "Kubernetes version set to: v$K8S_VERSION"
blank

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
export K8S_VERSION
export NODE_NAME
export POD_CIDR
export CONTAINERD_INSTALL_METHOD


