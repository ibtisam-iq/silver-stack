#!/usr/bin/env bash
# ===============================================================
# infra-bootstrap : Shared Core Library (common.sh)
#
# Provides:
#   • Strict shell safety
#   • Colorized logging
#   • UI helpers
#   • Root / sudo controls
#   • Execution visibility
#   • curl | bash SAFE execution
#   • Universal remote runner
#   • DRY-RUN execution mode
#
# This file is designed to be sourced by ALL scripts.
# ===============================================================
 
set -Eeuo pipefail
IFS=$'\n\t'

# ===================== Execution Mode Detection ==================
# Detect curl | bash vs direct execution
#
if [[ ! -t 0 ]]; then
  PIPE_MODE=1
  TMP_BASE="$(mktemp -d -t infra-bootstrap-XXXXXXXX)"
  trap 'rm -rf "$TMP_BASE" 2>/dev/null || true' EXIT
else
  PIPE_MODE=0
  TMP_BASE=""
fi

# ========================= DRY RUN MODE =========================
# Enable with:
#   DRY_RUN=1
#   or --dry-run flag in entrypoint scripts
#
DRY_RUN="${DRY_RUN:-0}"

# ========================= Colors ==============================
if [[ -t 1 ]]; then  
  readonly C_RESET="\033[0m"
  readonly C_BOLD="\033[1m"
  readonly C_DIM="\033[2m"
  readonly C_RED="\033[31m"
  readonly C_GREEN="\033[32m"
  readonly C_YELLOW="\033[33m"
  readonly C_BLUE="\033[34m"
  readonly C_MAGENTA="\033[35m"
  readonly C_CYAN="\033[36m"
else
  readonly C_RESET='' C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_MAGENTA='' C_CYAN=''
fi

# ========================= Logging =============================
info()  { printf "%b[INFO]%b    %s\n" "$C_BLUE"   "$C_RESET" "$*"; }
ok()    { printf "%b[ OK ]%b    %s\n" "$C_GREEN" "$C_RESET" "$*"; }
warn()  { printf "%b[WARN]%b    %s\n" "$C_YELLOW" "$C_RESET" "$*"; }
error() { printf "%b[ERR ]%b    %s\n" "$C_RED"   "$C_RESET" "$*" >&2; exit 1; }

# Bullet-style list entry (e.g. for tool/version lines)
item()  { printf " %b•%b %-14s %s\n" "$C_CYAN" "$C_RESET" "$1:" "$2"; }

# Simple blank line
blank() { printf "\n"; }

# Horizontal rule
hr() {
  printf "%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n" "$C_MAGENTA" "$C_RESET"
}

# Full line coloring
cmd() {
  printf "%b%b[CMD>]    %s%b\n" "$C_BOLD" "$C_CYAN" "$*" "$C_RESET"
}

# ========================= Section Heading ======================
section() {
  info "$1"
}

footer() {
  hr
  ok "$1"
  blank
}

# ===================== DRY-RUN Command Wrapper ==================
run_cmd() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf "%b[DRY ]%b    %s\n" "$C_DIM" "$C_RESET" "$*"
    return 0
  fi
  "$@"
}

if [[ "$DRY_RUN" == "1" ]]; then
  warn "DRY-RUN MODE ENABLED — no changes will be made"
  blank
fi

# ======================= System Validation ======================
require_root() {
  [[ ${EUID:-$(id -u)} -eq 0 ]] || error "This command must be run as root."
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || error "Required command missing: $1"
}

# ===================== Prevent Privileged Execution =====================
forbid_sudo() {

  # Block ONLY when: running as root, but invoked via sudo, and original user was NOT root
  if [[ ${EUID:-$(id -u)} -eq 0 ]] \
     && [[ -n "${SUDO_USER:-}" ]] \
     && [[ "${SUDO_USER}" != "root" ]]; then
    error "This script must NOT be run with sudo privileges."
  fi
}

# ===================== Privileged Execution Confirmation =====================
confirm_sudo_execution() {

  # Trigger ONLY when: running as root, invoked via sudo, and original user was NOT root
  if [[ ${EUID:-$(id -u)} -eq 0 ]] \
     && [[ -n "${SUDO_USER:-}" ]] \
     && [[ "${SUDO_USER}" != "root" ]]; then

    # warn "This script is running with elevated privileges via sudo."
    printf "%b[CONF]%b    Press Enter to continue, or Ctrl+C to abort..." \
      "$C_YELLOW" "$C_RESET"
    # IMPORTANT: force read from terminal, not stdin
    read -r _ </dev/tty || true
    blank
  fi
}

# ===================== Execution Visibility =====================
print_execution_user() {
  local effective_user

  # Effective user (who the process is actually running as)
  effective_user="$(id -un 2>/dev/null || echo unknown)"

  # Always print the effective execution user
  info "Execution user: ${effective_user}"

  # Special notice when running as root via sudo
  if [[ "$effective_user" == "root" ]] \
     && [[ -n "${SUDO_USER:-}" ]] \
     && [[ "${SUDO_USER}" != "root" ]]; then
    warn "Invoked via sudo privileges by user '${SUDO_USER}'"
    blank
  fi
}

# ========================== Remote Fetch =========================
fetch() {
  local url=$1
  curl -fsSL "$url" || error "Failed to fetch: $url"
}

# ===================== Universal Remote Runner ===================
# Safe for:
#   - curl | bash
#   - nested remote execution
#   - interactive scripts
#
run_remote_script() {
  local url="$1"
  local description="${2:-$(basename "$url")}"

  [[ -n "$url" ]] || error "run_remote_script: URL required"

  if [[ "$DRY_RUN" == "1" ]]; then
    printf "%b[DRY ]%b    Would execute: %s\n" "$C_DIM" "$C_RESET" "$description"
    printf "%b        URL: %s%b\n" "$C_DIM" "$url" "$C_RESET"
    blank
    return 0
  fi

  if [[ "$PIPE_MODE" -eq 1 ]]; then
    local script_path="$TMP_BASE/$(basename "$url")"
    info "Downloading $description"
    curl -fsSL "$url" -o "$script_path" || error "Download failed: $url"
    chmod +x "$script_path" 2>/dev/null || true
    bash "$script_path" || error "Execution failed: $description"
  else
    info "Executing $description"
    bash <(curl -fsSL "$url") || error "Execution failed: $description"
  fi
}

# ===================== Remote Library Loader =====================
# Safely sources a remote shell library into the CURRENT shell.
#
# This is REQUIRED for:
#   - common.sh dependencies
#   - ensure_kubeconfig.sh
#   - any file that defines functions/variables
#
# This function:
#   - Downloads the library to a temp file
#   - Sources it into the current shell
#   - Cleans up the temp file
#   - Works in curl | bash mode
#

source_remote_library() {
  local url="$1"
  local description="${2:-$(basename "$url")}"

  [[ -n "$url" ]] || error "source_remote_library: URL required"

  if [[ "$DRY_RUN" == "1" ]]; then
    printf "%b[DRY ]%b    Would source library: %s\n" "$C_DIM" "$C_RESET" "$description"
    printf "%b        URL: %s%b\n" "$C_DIM" "$url" "$C_RESET"
    blank
    return 0
  fi

  local tmp_file
  tmp_file="$(mktemp -t infra-bootstrap-XXXXXXXX.sh)"

  curl -fsSL "$url" -o "$tmp_file" || error "Failed to download $url"
  info "Library loaded: $description"
  blank

  # Source into CURRENT shell
  # shellcheck source=/dev/null
  source "$tmp_file" || error "Failed to source $description"

  rm -f "$tmp_file"
}

# ===================== Remote Execution Helpers ==================
run_remote_local() {
  run_remote_script "$1" "$2"
}

run_remote_sudo() {
  require_root
  run_remote_script "$1" "$2"
}

safe_run_remote_sudo() {
  require_root
  if ! run_remote_script "$1" "$2"; then
    warn "Remote component failed — continuing"
  fi
  blank
}

# ============================ UI ================================
banner() {
  printf "\n%b╔════════════════════════════════════════════════════════╗%b\n" "$C_CYAN" "$C_RESET"
  printf "%b║ infra-bootstrap — %s%b\n" "$C_CYAN" "$1" "$C_RESET"
  printf "%b╚════════════════════════════════════════════════════════╝%b\n" "$C_CYAN" "$C_RESET"
  blank
}

# ======================== Confirmation Prompt ========================

confirm_or_abort() {
  local prompt="$1"
  local max_attempts="${2:-3}"

  local attempt=1
  local response

  while [[ $attempt -le $max_attempts ]]; do
    read -rp "$prompt ($attempt of $max_attempts): " response

    [[ "$response" == "YES" ]] && return 0
    
    # Only warn if another attempt is still available
    if [[ $attempt -lt $max_attempts ]]; then
      blank
      warn "You must type exactly 'YES' to proceed."
      blank
    fi

    ((attempt++))
  done

  blank
  warn "Confirmation failed — aborted"
  blank
  return 1
}

# ===================== URL Constants ===========================

export K8S_BASE_URL="https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/kubernetes"
export PREFLIGHT_URL="https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/system-checks/preflight.sh"

export K8S_CNI_URL="${K8S_BASE_URL}/cni"
export INSTALL_CNI_URL="${K8S_CNI_URL}/install-cni.sh"
export INSTALL_CALICO_URL="${K8S_CNI_URL}/install-calico.sh"
export INSTALL_FLANNEL_URL="${K8S_CNI_URL}/install-flannel.sh"

export K8S_RUNTIME_URL="${K8S_BASE_URL}/runtime"
export K8S_PACKAGES_URL="${K8S_BASE_URL}/packages"
export K8S_MANIFESTS_URL="${K8S_BASE_URL}/manifests"
export K8S_MAINTENANCE_URL="${K8S_BASE_URL}/maintenance"

export VERSION_RESOLVER_URL="${K8S_BASE_URL}/lib/version-resolver.sh"
export ENSURE_KUBECONFIG_URL="${K8S_BASE_URL}/lib/ensure_kubeconfig.sh"

export INIT_CONTROL_PLANE_URL="${K8S_BASE_URL}/entrypoints/init-controlplane.sh"