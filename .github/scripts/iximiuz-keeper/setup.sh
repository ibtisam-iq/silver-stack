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
#
# OUTPUTS:
#   - labctl installed to $HOME/.iximiuz/labctl/bin
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
log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
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
    local labctl_path="$HOME/.iximiuz/labctl/bin/labctl"
    if [[ ! -x "$labctl_path" ]]; then
        log_error "labctl binary not found at: $labctl_path"
        return 1
    fi

    # Log version for debugging
    log_info "labctl version: $($labctl_path version)"

    # Add to PATH for current script
    export PATH="$HOME/.iximiuz/labctl/bin:$PATH"

    log_info "✅ labctl installed successfully"
}

# =============================================================================
# PHASE 2: Configure Authentication
# =============================================================================

configure_auth() {
    log_info "Configuring API authentication..."

    # Validate token is provided
    if [[ -z "${IXIMIUZ_ACCESS_TOKEN:-}" ]]; then
        log_error "IXIMIUZ_ACCESS_TOKEN environment variable not set"
        log_error ""
        log_error "Required action:"
        log_error "  1. Run: labctl auth login"
        log_error "  2. Extract: cat ~/.iximiuz/labctl/config.yaml | grep access_token"
        log_error "  3. Add to GitHub Secrets:"
        log_error "     Name: IXIMIUZ_ACCESS_TOKEN"
        log_error "     Value: <your-token>"
        return 1
    fi

    # Create config directory
    mkdir -p "$HOME/.iximiuz/labctl"

    # Generate config file
    cat > "$HOME/.iximiuz/labctl/config.yaml" <<EOF
base_url: https://labs.iximiuz.com
api_base_url: https://labs.iximiuz.com/api
session_id: ${IXIMIUZ_SESSION_ID}
access_token: ${IXIMIUZ_ACCESS_TOKEN}
plays_dir: $HOME/.iximiuz/labctl/plays
ssh_identity_file: $HOME/.ssh/iximiuz_labs_user
EOF

    # Secure permissions (owner read/write only)
    chmod 600 "$HOME/.iximiuz/labctl/config.yaml"

    log_info "✅ Authentication configured"
}

# =============================================================================
# PHASE 3: Verify Token Validity
# =============================================================================

verify_token() {
    log_info "Verifying API token validity..."

    # Test API call (minimal operation)
    if labctl playground list &>/dev/null; then
        log_info "✅ API token is valid and authorized"
        return 0
    else
        log_error "API authentication failed"
        log_error ""
        log_error "Possible causes:"
        log_error "  1. Token expired (30-day validity)"
        log_error "  2. Token revoked or invalid"
        log_error "  3. API connectivity issues"
        log_error ""
        log_error "Resolution: Renew token via 'labctl auth login'"
        return 1
    fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    log_info "Starting environment setup..."

    install_labctl || exit 1
    configure_auth || exit 1
    verify_token || exit 1

    log_info "✅ Setup completed successfully"
}

main "$@"
