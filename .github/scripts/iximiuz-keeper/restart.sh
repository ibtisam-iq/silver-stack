#!/usr/bin/env bash
# =============================================================================
# iximiuz Keeper - Playground Restart Operations
# =============================================================================
#
# PURPOSE:
#   Restart ALL stopped playground instances, one by one.
#   A failure on one playground never aborts the rest.
#
# INPUTS:
#   - STOPPED_IDS: Space-separated list of playground IDs to restart
#   - RESTART_WAIT_SECONDS: Boot wait time after restart (default: 45)
#
# OUTPUTS (via $GITHUB_OUTPUT):
#   - restarted:     true/false
#   - restart_count: Number of successful restarts
#   - failed_count:  Number of failed restarts
#   - restarted_ids: Space-separated list of successfully restarted IDs
#   - restart_time:  ISO8601 timestamp of restart operation
#
# EXIT CODES:
#   0 - All restarts succeeded (or no failures)
#   1 - One or more restarts failed (partial success still reported)
#
# =============================================================================

set -euo pipefail

readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

restart_playgrounds() {
    local stopped_ids="${STOPPED_IDS:-}"
    local restart_wait="${RESTART_WAIT_SECONDS:-45}"

    if [[ -z "$stopped_ids" ]]; then
        log_error "No stopped playground IDs provided (STOPPED_IDS is empty)"
        return 1
    fi

    local total
    total=$(echo "$stopped_ids" | wc -w | tr -d ' ')

    log_info "Initiating restart sequence..."
    log_info "Target count: $total"
    echo ""

    local restart_count=0
    local failed_count=0
    local restarted_list=""
    local failed_list=""

    for playground_id in $stopped_ids; do
        echo "\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501"
        log_info "\ud83d\udd04 Processing: $playground_id"
        echo "\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501"

        # -------------------------------------------------------------------
        # KEY FIX: run labctl in a subshell with || so that a failure here
        # does NOT trigger set -e and kill the entire script.
        # All playgrounds are always attempted regardless of individual failures.
        # -------------------------------------------------------------------
        local output
        if output=$(labctl playground restart "$playground_id" 2>&1); then
            # ---------------------------------------------------------------
            # Use $((x+1)) NOT ((x++)) — ((x++)) exits 1 when x=0 under set -e
            # ---------------------------------------------------------------
            restart_count=$(( restart_count + 1 ))
            restarted_list="${restarted_list:+$restarted_list }$playground_id"
            log_info "\u2705 Successfully restarted: $playground_id"
            echo "$output"
        else
            failed_count=$(( failed_count + 1 ))
            failed_list="${failed_list:+$failed_list }$playground_id"
            log_error "\u274c Failed to restart: $playground_id"
            log_error "Raw labctl output:"
            echo "$output" | while read -r line; do
                log_error "  $line"
            done
        fi
        echo ""
    done

    # -----------------------------------------------------------------------
    # SUMMARY REPORT — always printed even if some failed
    # -----------------------------------------------------------------------
    echo "\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501"
    echo "\ud83d\udcca Restart Summary"
    echo "\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501"
    echo "Total targeted:  $total"
    echo "\u2705 Successful:     $restart_count"
    echo "\u274c Failed:          $failed_count"
    [[ -n "$restarted_list" ]] && echo "Restarted IDs:   $restarted_list"
    [[ -n "$failed_list"    ]] && echo "Failed IDs:      $failed_list"
    echo "\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501"

    # Boot wait for any successful restart
    if [[ $restart_count -gt 0 ]]; then
        echo ""
        log_info "\u23f3 Waiting ${restart_wait}s for playground boot completion..."
        sleep "$restart_wait"
        log_info "\u2705 Boot wait completed"
    fi

    # Export outputs regardless of success/failure
    local restarted_flag="false"
    [[ $restart_count -gt 0 ]] && restarted_flag="true"

    {
        echo "restarted=$restarted_flag"
        echo "restart_count=$restart_count"
        echo "failed_count=$failed_count"
        echo "restarted_ids=$restarted_list"
        echo "failed_ids=$failed_list"
        echo "restart_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    } >> "$GITHUB_OUTPUT"

    # Exit non-zero only if there were failures — allows caller to detect
    # partial success. The report step uses 'if: always()' so it still runs.
    if [[ $failed_count -gt 0 ]]; then
        log_error "$failed_count of $total restart(s) failed"
        return 1
    fi

    log_info "\u2705 All $restart_count playground(s) restarted successfully"
}

main() {
    restart_playgrounds
}

main "$@"
