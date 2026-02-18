#!/usr/bin/env bash
# =============================================================================
# iximiuz Keeper - Playground Discovery
# =============================================================================
#
# PURPOSE:
#   Auto-discover all playground instances and categorize by state
#
# RESPONSIBILITIES:
#   - Query iximiuz API for playground inventory
#   - Parse and categorize by state (STOPPED/RUNNING)
#   - Export state variables for subsequent workflow steps
#
# INPUTS:
#   - None (reads from labctl config)
#
# OUTPUTS:
#   - GitHub Actions outputs (via $GITHUB_OUTPUT):
#     - stopped_ids: Space-separated list of stopped playground IDs
#     - running_ids: Space-separated list of running playground IDs
#     - total_count: Total playground count
#     - stopped_count: Count of stopped playgrounds
#     - running_count: Count of running playgrounds
#     - action_needed: true/false (if restart required)
#
# =============================================================================

set -euo pipefail

readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# =============================================================================
# DISCOVERY LOGIC
# =============================================================================

discover_playgrounds() {
    log_info "Querying iximiuz API for playground inventory..."

    # Fetch playground list
    local playground_list
    if ! playground_list=$(labctl playground list 2>&1); then
        log_error "Failed to retrieve playground list"
        echo "$playground_list"
        return 1
    fi

    echo "$playground_list"
    echo ""

    # Initialize state tracking
    local stopped_ids=""
    local running_ids=""
    local total_count=0

    # Parse playground list
    while IFS= read -r line; do
        # Skip header and empty lines
        [[ "$line" =~ ^ID ]] && continue
        [[ -z "$line" ]] && continue

        local id state
        id=$(echo "$line" | awk '{print $1}')
        state=$(echo "$line" | awk '{print $4}')

        # Validate ID
        [[ -z "$id" || "$id" == "ID" ]] && continue

        ((total_count++))

        # Categorize by state
        case "$state" in
            STOPPED)
                stopped_ids="${stopped_ids:+$stopped_ids }$id"
                echo "🔴 STOPPED: $id"
                ;;
            RUNNING)
                running_ids="${running_ids:+$running_ids }$id"
                echo "🟢 RUNNING: $id"
                ;;
            *)
                echo "⚪ $state: $id"
                ;;
        esac
    done <<< "$playground_list"

    # Calculate counts
    local stopped_count running_count
    stopped_count=$(echo "$stopped_ids" | wc -w)
    running_count=$(echo "$running_ids" | wc -w)

    # Log summary
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Discovery Summary"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Total:   $total_count"
    echo "Stopped: $stopped_count"
    echo "Running: $running_count"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Export to GitHub Actions outputs
    {
        echo "stopped_ids=$stopped_ids"
        echo "running_ids=$running_ids"
        echo "total_count=$total_count"
        echo "stopped_count=$stopped_count"
        echo "running_count=$running_count"
    } >> "$GITHUB_OUTPUT"

    # Determine action needed
    if [[ -n "$stopped_ids" ]]; then
        echo "action_needed=true" >> "$GITHUB_OUTPUT"
        log_info "⚠️ Action required: $stopped_count playgrounds need restart"
    else
        echo "action_needed=false" >> "$GITHUB_OUTPUT"
        log_info "✅ All playgrounds operational"
    fi
}

main() {
    discover_playgrounds
}

main "$@"
