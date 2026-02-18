#!/usr/bin/env bash
# =============================================================================
# iximiuz Keeper - Playground Restart Operations
# =============================================================================
#
# PURPOSE:
#   Restart all stopped playground instances
#
# INPUTS:
#   - STOPPED_IDS: Space-separated list of playground IDs to restart
#   - RESTART_WAIT_SECONDS: Boot wait time after restart
#
# OUTPUTS:
#   - GitHub Actions outputs:
#     - restarted: true/false
#     - restart_count: Number of successful restarts
#     - failed_count: Number of failed restarts
#     - restarted_ids: Space-separated list of successfully restarted IDs
#     - restart_time: ISO8601 timestamp of restart operation
#
# =============================================================================

set -euo pipefail

readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

restart_playgrounds() {
    local stopped_ids="${STOPPED_IDS:-}"
    local restart_wait="${RESTART_WAIT_SECONDS:-45}"

    if [[ -z "$stopped_ids" ]]; then
        log_error "No stopped playground IDs provided"
        return 1
    fi

    log_info "Initiating restart sequence..."
    log_info "Target count: $(echo "$stopped_ids" | wc -w)"
    echo ""

    local restart_count=0
    local failed_count=0
    local restarted_list=""

    for playground_id in $stopped_ids; do
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🔄 Processing: $playground_id"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        if labctl playground restart "$playground_id" 2>&1; then
            ((restart_count++))
            restarted_list="${restarted_list:+$restarted_list }$playground_id"
            log_info "✅ Restart successful"
        else
            ((failed_count++))
            log_error "❌ Restart failed"
        fi
        echo ""
    done

    # Summary
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Restart Summary"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ Successful: $restart_count"
    echo "❌ Failed:     $failed_count"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Wait for boot
    if [[ $restart_count -gt 0 ]]; then
        echo ""
        log_info "⏳ Waiting ${restart_wait}s for boot completion..."
        sleep "$restart_wait"
        log_info "✅ Boot wait completed"
    fi

    # Export outputs
    {
        echo "restarted=true"
        echo "restart_count=$restart_count"
        echo "failed_count=$failed_count"
        echo "restarted_ids=$restarted_list"
        echo "restart_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    } >> "$GITHUB_OUTPUT"
}

main() {
    restart_playgrounds
}

main "$@"
