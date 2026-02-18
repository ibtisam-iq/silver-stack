#!/usr/bin/env bash
# =============================================================================
# iximiuz Keeper - Health Check
# =============================================================================
#
# PURPOSE:
#   Verify external service availability
#
# INPUTS:
#   - JENKINS_EXTERNAL_URL: Service URL to check
#   - HEALTH_CHECK_RETRIES: Number of retry attempts
#   - HEALTH_CHECK_INTERVAL: Seconds between retries
#
# OUTPUTS:
#   - jenkins_status: UP/DOWN
#
# =============================================================================

set -euo pipefail

readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

health_check() {
    local url="${JENKINS_EXTERNAL_URL:-}"
    local retries="${HEALTH_CHECK_RETRIES:-3}"
    local interval="${HEALTH_CHECK_INTERVAL:-10}"

    if [[ -z "$url" ]]; then
        log_warn "No external URL configured, skipping health check"
        return 0
    fi

    log_info "Starting health verification..."
    log_info "Target: $url/login"
    echo ""

    local healthy=false

    for ((i=1; i<=retries; i++)); do
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Attempt $i/$retries"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        local http_code
        http_code=$(curl -o /dev/null -s -w "%{http_code}" -m 10 "$url/login" || echo "000")
        echo "HTTP Status: $http_code"

        if [[ "$http_code" == "200" || "$http_code" == "403" ]]; then
            healthy=true
            echo "jenkins_status=UP" >> "$GITHUB_OUTPUT"
            log_info "✅ Service is accessible"
            break
        fi

        if [[ $i -lt $retries ]]; then
            log_warn "⚠️ Check failed, retrying in ${interval}s..."
            sleep "$interval"
        fi
    done

    if [[ "$healthy" == false ]]; then
        echo "jenkins_status=DOWN" >> "$GITHUB_OUTPUT"
        log_error "❌ Health check failed after $retries attempts"
    fi
}

main() {
    health_check
}

main "$@"
