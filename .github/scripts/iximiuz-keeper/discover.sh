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
# NOTES on column layout:
#   labctl output format:
#     PLAYGROUND ID   NAME   CREATED         STATUS    LINK
#     <hex-id>        <name> <N unit ago>    STOPPED
#     <hex-id>        <name> <N unit ago>    RUNNING   <url>
#
#   The CREATED field is variable width ("1 day ago", "2 months ago", etc.)
#   so STATUS is NOT at a fixed awk column index.
#   We scan all fields for the known STATUS tokens instead.
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

# =============================================================================
# DISCOVERY LOGIC
# =============================================================================

discover_playgrounds() {
    log_info "Querying iximiuz API for playground inventory..."

    # Fetch playground list
    local playground_list
    if ! playground_list=$(labctl playground list 2>&1); then
        log_error "Failed to retrieve playground list"
        log_error "Raw output: $playground_list"
        return 1
    fi

    echo "$playground_list"
    echo ""

    # Initialize state tracking
    local stopped_ids=""
    local running_ids=""
    local total_count=0

    # Parse playground list line by line
    while IFS= read -r line; do

        # Skip header line: "PLAYGROUND ID   NAME   CREATED   STATUS   LINK"
        [[ "$line" =~ ^PLAYGROUND ]] && continue

        # Skip empty lines
        [[ -z "$line" ]] && continue

        # Extract playground ID (always first field - a hex string)
        local id
        id=$(echo "$line" | awk '{print $1}')

        # Skip if ID is empty or is a header word
        [[ -z "$id" || "$id" == "PLAYGROUND" || "$id" == "ID" ]] && continue

        # ---------------------------------------------------------------
        # STATUS is NOT at a fixed column because CREATED is variable width:
        #   "1 day ago"    -> STATUS at $5
        #   "2 months ago" -> STATUS at $5
        #   "just now"     -> STATUS at $4
        #
        # Robust fix: scan every field in the line for a known STATUS token.
        # ---------------------------------------------------------------
        local state="UNKNOWN"
        if echo "$line" | grep -qw "STOPPED"; then
            state="STOPPED"
        elif echo "$line" | grep -qw "RUNNING"; then
            state="RUNNING"
        fi

        # Use $((x+1)) NOT ((x++)) — ((x++)) exits 1 when x=0 under set -e
        total_count=$(( total_count + 1 ))

        # Categorize by state
        case "$state" in
            STOPPED)
                stopped_ids="${stopped_ids:+$stopped_ids }$id"
                log_info "🔴 STOPPED: $id"
                ;;
            RUNNING)
                running_ids="${running_ids:+$running_ids }$id"
                log_info "🟢 RUNNING: $id"
                ;;
            *)
                log_warn "⚪ UNKNOWN state for: $id (raw line: $line)"
                ;;
        esac
    done <<< "$playground_list"

    # Calculate counts
    local stopped_count running_count
    stopped_count=$(echo "$stopped_ids" | wc -w | tr -d ' ')
    running_count=$(echo "$running_ids"  | wc -w | tr -d ' ')

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

    # Determine if restart action is needed
    if [[ -n "$stopped_ids" ]]; then
        echo "action_needed=true" >> "$GITHUB_OUTPUT"
        log_info "⚠️  Action required: $stopped_count playground(s) need restart"
    else
        echo "action_needed=false" >> "$GITHUB_OUTPUT"
        log_info "✅ All playgrounds operational"
    fi
}

main() {
    discover_playgrounds
}

main "$@"
