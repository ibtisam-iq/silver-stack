#!/usr/bin/env bash
# =============================================================================
# iximiuz Keeper - Keep-Alive Signals
# =============================================================================
#
# PURPOSE:
#   Send keep-alive signals to prevent inactivity timeout
#
# STRATEGY:
#   - Layer 1: HTTP keep-alive (external services)
#   - Layer 2: SSH keep-alive (internal playground activity)
#
# INPUTS:
#   - RUNNING_IDS: Space-separated list of running playground IDs
#   - JENKINS_EXTERNAL_URL: External service URL
#
# =============================================================================

set -euo pipefail

readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

keep_alive() {
    local running_ids="${RUNNING_IDS:-}"
    local external_url="${JENKINS_EXTERNAL_URL:-}"

    if [[ -z "$running_ids" ]]; then
        log_warn "No running playgrounds to maintain"
        return 0
    fi

    log_info "🏓 Initiating keep-alive for $(echo "$running_ids" | wc -w) playgrounds"
    echo ""

    # Layer 1: HTTP Keep-Alive
    if [[ -n "$external_url" ]]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Layer 1: HTTP Keep-Alive"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        for endpoint in "/" "/login" "/api/json"; do
            echo "→ $external_url$endpoint"
            curl -s -o /dev/null -m 5 "$external_url$endpoint" || true
        done

        log_info "✅ HTTP keep-alive completed"
        echo ""
    fi

    # Layer 2: SSH Keep-Alive
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Layer 2: SSH Keep-Alive"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local ssh_success=0
    local ssh_failed=0

    for playground_id in $running_ids; do
        echo "→ Playground: $playground_id"

        if labctl ssh "$playground_id" -- "echo 'keep-alive-$(date +%s)'" 2>/dev/null; then
            ((ssh_success++))
            echo "  ✅ Success"
        else
            ((ssh_failed++))
            echo "  ⚠️ Failed"
        fi
    done

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Keep-Alive Summary"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "HTTP: ✅ Completed"
    echo "SSH:  ✅ $ssh_success successful"
    [[ $ssh_failed -gt 0 ]] && echo "      ⚠️ $ssh_failed failed"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

main() {
    keep_alive
}

main "$@"
