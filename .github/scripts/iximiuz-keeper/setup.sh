#!/usr/bin/env bash
# =============================================================================
# iximiuz Keeper - Setup & Authentication
# =============================================================================
#
# PURPOSE:
#   Install labctl CLI and configure API authentication
#
# RESPONSIBILITIES:
#   - Install labctl from official source
#   - Configure authentication with API token
#   - Verify token validity
#   - Fail fast on setup errors
#
# INPUTS:
#   - IXIMIUZ_ACCESS_TOKEN (environment variable, from GitHub Secrets)
#   - IXIMIUZ_SESSION_ID   (environment variable, from GitHub Secrets)
#
# OUTPUTS:
#   - labctl installed to $HOME/.iximiuz/labctl/bin
#   - labctl binary added to $GITHUB_PATH (available to ALL subsequent steps)
#   - config.yaml created at $HOME/.iximiuz/labctl/config.yaml
#   - Exit code: 0=success, 1=failure
#
# =============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Terminal colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# =============================================================================
# PHASE 1: Install labctl CLI
# =============================================================================

install_labctl() {
    log_info "Installing labctl CLI..."

    # Download and execute official installation script
    # -s: Silent (no progress bar)
    # -f: Fail on HTTP errors
    # -L: Follow redirects
    if ! curl -sfL "https://labs.iximiuz.com/cli/install.sh" | sh; then
        log_error "Failed to install labctl"
        return 1
    fi

    # Verify installation
    local labctl_bin="$HOME/.iximiuz/labctl/bin"
    local labctl_path="$labctl_bin/labctl"
    if [[ ! -x "$labctl_path" ]]; then
        log_error "labctl binary not found at: $labctl_path"
        return 1
    fi

    # Log version for debugging
    log_info "labctl version: $($labctl_path version)"

    # Add to PATH for the CURRENT step
    export PATH="$labctl_bin:$PATH"

    # -----------------------------------------------------------------------
    # CRITICAL: Persist PATH to GITHUB_PATH so ALL subsequent workflow steps
    # (discover.sh, restart.sh, keep-alive.sh, etc.) can call `labctl` directly.
    # Each GitHub Actions step runs in its own shell — export alone is not enough.
    # -----------------------------------------------------------------------
    echo "$labctl_bin" >> "$GITHUB_PATH"
    log_info "labctl added to GITHUB_PATH (available to all subsequent steps)"

    log_info "\u2705 labctl installed successfully"
}

# =============================================================================
# PHASE 2: Configure Authentication
# =============================================================================

configure_auth() {
    log_info "Configuring API authentication..."

    # ------------------------------------------------------------------
    # NOTE: Both checks MUST happen here — before the heredoc — because
    # bash disables set -e inside any function called with "func || fallback".
    # Without explicit guards, an unbound variable in the heredoc is silently
    # skipped, writing a broken config.yaml, and verify_token fails later.
    # ------------------------------------------------------------------

    # Validate IXIMIUZ_ACCESS_TOKEN
    if [[ -z "${IXIMIUZ_ACCESS_TOKEN:-}" ]]; then
        log_error "IXIMIUZ_ACCESS_TOKEN environment variable not set"
        log_error "  \u2192 Run: labctl auth login"
        log_error "  \u2192 Extract: cat ~/.iximiuz/labctl/config.yaml | grep access_token"
        log_error "  \u2192 Add to GitHub Secrets: IXIMIUZ_ACCESS_TOKEN"
        return 1
    fi

    # Validate IXIMIUZ_SESSION_ID
    if [[ -z "${IXIMIUZ_SESSION_ID:-}" ]]; then
        log_error "IXIMIUZ_SESSION_ID environment variable not set"
        log_error "  \u2192 Extract: cat ~/.iximiuz/labctl/config.yaml | grep session_id"
        log_error "  \u2192 Add to GitHub Secrets: IXIMIUZ_SESSION_ID"
        return 1
    fi

    # Create config directory
    mkdir -p "$HOME/.iximiuz/labctl"

    # Generate config file (all fields required by labctl)
    cat > "$HOME/.iximiuz/labctl/config.yaml" <<EOF
base_url: https://labs.iximiuz.com
api_base_url: https://labs.iximiuz.com/api
session_id: ${IXIMIUZ_SESSION_ID}
access_token: ${IXIMIUZ_ACCESS_TOKEN}
plays_dir: $HOME/.iximiuz/labctl/plays
EOF

    # Secure permissions (owner read/write only)
    chmod 600 "$HOME/.iximiuz/labctl/config.yaml"

    # Confirm config was written (non-sensitive fields only)
    log_info "Config written ($(wc -l < "$HOME/.iximiuz/labctl/config.yaml") lines):"
    grep -v "access_token\|session_id" "$HOME/.iximiuz/labctl/config.yaml" | while read -r line; do
        log_info "  $line"
    done
    log_info "  session_id: [REDACTED]"
    log_info "  access_token: [REDACTED]"

    log_info "\u2705 Authentication configured"
}

# =============================================================================
# PHASE 3: Verify Token Validity
# =============================================================================

verify_token() {
    log_info "Verifying API token validity..."

    local output
    output=$(labctl playground list 2>&1) && {
        log_info "\u2705 API token is valid and authorized"
        return 0
    } || {
        log_error "API authentication failed"
        log_error ""
        log_error "Raw labctl output:"
        echo "$output" | while read -r line; do
            log_error "  $line"
        done
        log_error ""
        log_error "Possible causes:"
        log_error "  1. Token expired (30-day validity)"
        log_error "  2. Token revoked or invalid"
        log_error "  3. session_id / access_token mismatch"
        log_error "  4. API connectivity issues"
        log_error ""
        log_error "Resolution: Renew token via 'labctl auth login'"
        return 1
    }
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    log_info "Starting environment setup..."

    install_labctl  || exit 1
    configure_auth  || exit 1
    verify_token    || exit 1

    log_info "\u2705 Setup completed successfully"
}

main "$@"
