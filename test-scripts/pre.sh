#!/usr/bin/env bash
# =====================================================================
# infra-bootstrap : Installed Tools & Version Audit (Enterprise Grade)
# - Clean, column-aligned, premium UI (Option A)
# - Modular detection for tricky tools (docker compose, k9s, helm, etc.)
# - Quiet by default; optional slow-printing for UX
# =====================================================================

set -Eeuo pipefail
IFS=$'\n\t'


# ---------------------- REAL USER DETECTION ----------------------
# Works even when running "sudo bash", "sudo -i", via SSH, or root shells.
if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    REAL_USER="$SUDO_USER"
else
    # logname fails in non-tty; fallback to who; fallback to $USER
    REAL_USER="$(logname 2>/dev/null || who | awk '{print $1}' | head -n1 || echo "$USER")"
fi

# If still empty, force root
REAL_USER="${REAL_USER:-root}"

# Fetch home reliably
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"

# Fallback: if still empty → assume /root
REAL_HOME="${REAL_HOME:-/root}"

# ---------------------- FIX USER ENV ----------------------
# Ensure all tools installed under user home resolve correctly while under sudo
export HOME="$REAL_HOME"

# ---------------------- PATH FIX (universal) ----------------------
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

USER_PATHS=(
    "$REAL_HOME/bin"
    "$REAL_HOME/.local/bin"
    "$REAL_HOME/.cargo/bin"
    "$REAL_HOME/go/bin"
    "/usr/local/go/bin"
)

for d in "${USER_PATHS[@]}"; do
    [[ -d "$d" ]] && PATH="$d:$PATH"
done

export PATH


# ----------------------- CONFIG -----------------------
# If > 0 then each line will sleep for this many seconds (human-read feel)
SLOW_PRINT="${SLOW_PRINT:-1}"

# Where to fetch common helper UI functions/colors from
COMMON_URL="https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/lib/common.sh"

# ------------------- Load common.sh safely -------------------
tmp_common="$(mktemp)"
if ! curl -fsSL "$COMMON_URL" -o "$tmp_common"; then
    echo "common.sh failed to load from $COMMON_URL" >&2
    rm -f "$tmp_common"
    exit 1
fi
# shellcheck disable=SC1090
source "$tmp_common"
rm -f "$tmp_common"

# ------------------- Preflight enforced -------------------
PRE_URL="https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/system-checks/preflight.sh"
info "Preflight check running..."
if ! out=$(bash <(curl -fsSL "$PRE_URL") 2>&1); then
    error "Preflight failed — stopping version audit."
    printf "\nDetails:\n%s\n" "$out"
    exit 1
fi
ok "Preflight passed!"
blank

# ------------------- Utilities -------------------
# prints one nicely formatted line with optional delay
print_line() {
    printf "%s\n" "$1"

    if [[ "${SLOW_PRINT:-0}" -gt 0 ]]; then
        sleep "$SLOW_PRINT"
    fi
}

# safe extractor helpers
extract_semver() {
    # extracts first semver-like string from stdin
    grep -Eo 'v?[0-9]+(\.[0-9]+){1,}' | head -n1 | sed 's/^v//'
}

# safe command version call wrapper (prevents unbound var failures)
run_quiet() {
    # use command -v before calling to avoid noisy errors where appropriate
    "$@" 2>/dev/null || true
}

# ------------------- Modular version resolvers -------------------
# For clarity: each tricky tool has its own function.
get_ver_docker() {
    run_quiet docker --version | awk '{print $3}' | tr -d ',' || echo ""
}

get_ver_compose() {
    # supports: docker compose (plugin), docker-compose, standalone cli-plugins
    # attempt docker compose (new plugin)
    if docker compose version >/dev/null 2>&1; then
        docker compose version | awk 'NR==1 {for(i=1;i<=NF;i++) if($i~/v?[0-9]+\.[0-9]+(\.[0-9]+)?/){gsub(/^v/,"",$i); print $i; exit}}'
        return
    fi

    # docker-compose (legacy)
    if command -v docker-compose >/dev/null 2>&1; then
        docker-compose version 2>/dev/null | awk 'NR==1 {for(i=1;i<=NF;i++) if($i~/[0-9]+\.[0-9]+(\.[0-9]+)?/){print $i; exit}}'
        return
    fi

    # cli-plugins locations
    if [[ -x "/usr/lib/docker/cli-plugins/docker-compose" ]]; then
        /usr/lib/docker/cli-plugins/docker-compose version 2>/dev/null | awk 'NR==1 {for(i=1;i<=NF;i++) if($i~/v?[0-9]+\.[0-9]+(\.[0-9]+)?/){gsub(/^v/,"",$i); print $i; exit}}'
        return
    fi
    if [[ -x "$HOME/.docker/cli-plugins/docker-compose" ]]; then
        "$HOME/.docker/cli-plugins/docker-compose" version 2>/dev/null | awk 'NR==1 {for(i=1;i<=NF;i++) if($i~/v?[0-9]+\.[0-9]+(\.[0-9]+)?/){gsub(/^v/,"",$i); print $i; exit}}'
        return
    fi

    echo ""
}

get_ver_kubectl() {
    run_quiet kubectl version --client --output=json 2>/dev/null | jq -r .clientVersion.gitVersion 2>/dev/null | sed 's/^v//' || \
    run_quiet kubectl version --client 2>/dev/null | extract_semver || echo ""
}

get_ver_k9s() {
    run_quiet k9s version --short 2>/dev/null | extract_semver || \
    run_quiet k9s version 2>/dev/null | extract_semver || \
    run_quiet k9s --version 2>/dev/null | extract_semver || echo ""
}

get_ver_helm() {
    run_quiet helm version --short 2>/dev/null | cut -d'+' -f1 | sed 's/^v//' || echo ""
}

get_ver_eksctl() {
    run_quiet eksctl version 2>/dev/null | sed 's/^v//' | awk '{print $1}' || echo ""
}

get_ver_kind() {
    run_quiet kind version 2>/dev/null | sed -n 's/^kind v//p' | awk '{print $1}' || echo ""
}

get_ver_etcdctl() {
    run_quiet etcdctl version 2>/dev/null | awk '/etcdctl/ {print $3}' || echo ""
}

get_ver_kustomize() {
    run_quiet kustomize version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || echo ""
}

get_ver_minikube() {
    run_quiet minikube version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || echo ""
}

get_ver_aws_iam_authenticator() {
    # aws-iam-authenticator prints either "Version: 0.7.9" or a json
    run_quiet aws-iam-authenticator version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || echo ""
}

get_ver_kubelogin() {
    run_quiet kubelogin --version 2>/dev/null | awk '{print $3}' | sed 's/^v//' || echo ""
}

# generic resolvers for many tools (single-line extraction)
get_ver_simple() {
    case "$1" in
        python3) python3 -V 2>/dev/null | awk '{print $2}' ;;
        go) go version 2>/dev/null | awk '{print $3}' | cut -c3- ;;
        node) node -v 2>/dev/null | cut -c2- ;;
        ruby) ruby -v 2>/dev/null | awk '{print $2}' ;;
        rust) rustc -V 2>/dev/null | awk '{print $2}' ;;
        java) java -version 2>&1 | awk -F\" '/version/ {print $2}' ;;
        containerd) containerd --version 2>/dev/null | awk '{print $3}' | sed 's/^v//' ;;
        runc) runc --version 2>/dev/null | awk '{print $3}' ;;
        ansible) ansible --version 2>/dev/null | awk 'NR==1{gsub(/\]|\[/,"",$3); print $3}' ;;
        jenkins) jenkins --version 2>/dev/null | awk '{print $1}' ;;
        terraform) terraform version 2>/dev/null | awk 'NR==1{print $2}' | sed 's/^v//' ;;
        packer) packer version 2>/dev/null | awk '{print $2}' | sed 's/^v//' ;;
        vagrant) vagrant --version 2>/dev/null | awk '{print $2}' ;;
        podman) podman --version 2>/dev/null | awk '{print $3}' ;;
        buildah) buildah --version 2>/dev/null | awk '{print $3}' ;;
        kubectl) get_ver_kubectl ;;
        k9s) get_ver_k9s ;;
        helm) get_ver_helm ;;
        eksctl) get_ver_eksctl ;;
        kind) get_ver_kind ;;
        crictl) crictl --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 ;;
        etcdctl) get_ver_etcdctl ;;
        kustomize) get_ver_kustomize ;;
        minikube) get_ver_minikube ;;
        aws-iam-authenticator) get_ver_aws_iam_authenticator ;;
        kubelogin) get_ver_kubelogin ;;
        trivy) trivy --version 2>/dev/null | awk 'NR==1{print $2}' ;;
        vault) vault version 2>/dev/null | awk '{print $2}' ;;
        lynis) lynis show version 2>/dev/null | awk '{print $3}' ;;
        falco) falco --version 2>/dev/null | awk '{print $3}' ;;
        bandit) bandit --version 2>&1 | awk '{print $2}' ;;
        snyk) snyk -v 2>/dev/null ;;
        npm) npm -v 2>/dev/null ;;
        pip) pip -V 2>/dev/null | awk '{print $2}' ;;
        pip3) pip3 -V 2>/dev/null | awk '{print $2}' ;;
        make) make -v 2>/dev/null | head -n1 | awk '{print $3}' ;;
        gcc) gcc -v 2>&1 | awk -F" " '/gcc version/ {print $3}' ;;
        g++) g++ -v 2>&1 | awk '/gcc version/ {print $3}' ;;
        cmake) cmake --version 2>/dev/null | head -n1 | awk '{print $3}' ;;
        pytest) pytest --version 2>/dev/null | awk '{print $2}' ;;
        maven) mvn -version 2>/dev/null | head -n1 | awk '{print $3}' ;;
        gradle) gradle -v 2>/dev/null | awk '/Gradle/ {print $2}' ;;
        mkdocs) mkdocs --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 ;;
        shellcheck) shellcheck --version 2>/dev/null | awk -F': ' '/version:/ {print $2}' ;;
        yamllint) yamllint --version 2>/dev/null | awk '{print $2}' ;;
        golangci-lint) golangci-lint version 2>/dev/null | awk '{print $4}' ;;
        aws) aws --version 2>&1 | awk -F/ '{print $2}' | cut -d' ' -f1 ;;
        gcloud) gcloud version 2>/dev/null | awk '/Google Cloud SDK/ {print $4}' ;;
        doctl) doctl version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 ;;
        azure|az)
        ver=$(az version 2>/dev/null | jq -r '."azure-cli"' 2>/dev/null)
        if [[ -z "$ver" ]]; then
            # fallback: extract any x.y.z from raw text
            ver=$(az version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
        fi
        ;;

        *) echo "" ;;
    esac
}

# ------------------- Dispatcher -------------------
get_version() {
    tool="$1"

    # Compose is special: don't require command -v for docker compose detection
    if [[ "$tool" != "compose" ]]; then
        if ! command -v "$tool" >/dev/null 2>&1; then
            # For some tools we may still detect via alternate helper commands
            case "$tool" in
                docker) : ;; # docker handled below by get_ver_docker
                *) printf "%b[ NOT INSTALLED ]%b" "$C_RED" "$C_RESET"; return ;;
            esac
        fi
    fi

    ver=""
    case "$tool" in
        docker) ver=$(get_ver_docker) ;;
        compose) ver=$(get_ver_compose) ;;
        # Kubernetes stack (delegated)
        kubectl|k9s|helm|eksctl|kind|crictl|etcdctl|kustomize|minikube|aws-iam-authenticator|kubelogin)
            ver=$(get_ver_simple "$tool") ;;
        # Programming & infra (generic)
        python3|go|node|ruby|rust|java|containerd|runc|ansible|jenkins|terraform|packer|vagrant|podman|buildah)
            ver=$(get_ver_simple "$tool") ;;
        # Security / DevSecOps
        trivy|vault|lynis|falco|bandit|snyk)
            ver=$(get_ver_simple "$tool") ;;
        # Build & Test
        npm|pip|pip3|make|gcc|g++|cmake|pytest|maven|gradle|mkdocs|shellcheck|yamllint|golangci-lint)
            ver=$(get_ver_simple "$tool") ;;
        # Cloud providers
        aws|gcloud|doctl|azure|az)
            ver=$(get_ver_simple "$tool") ;;
        *)
            ver=$(get_ver_simple "$tool") ;;
    esac

    if [[ -z "${ver:-}" ]]; then
        printf "%b[ NOT INSTALLED ]%b" "$C_RED" "$C_RESET"
    else
        printf "%b%-10s%b" "$C_GREEN" "$ver" "$C_RESET"
    fi
}

# ------------------- Layout Helpers -------------------
# Build an ordered list of tools for each category (same as your original)
lang=(python3 go node ruby rust java)
devops=(docker compose containerd runc ansible jenkins terraform packer vagrant podman buildah)
kube=(kubectl k9s helm eksctl kind crictl etcdctl kustomize minikube aws-iam-authenticator kubelogin)
cloud=(aws gcloud doctl azure)
sec=(trivy vault lynis falco bandit snyk)
build=(npm pip pip3 make gcc g++ cmake pytest maven gradle mkdocs shellcheck yamllint golangci-lint)

# Flatten tool names to compute max width dynamically
alltools=("${lang[@]}" "${devops[@]}" "${kube[@]}" "${cloud[@]}" "${sec[@]}" "${build[@]}")

# Compute max length for "label" column
max_len=0
for t in "${alltools[@]}"; do
    # human-friendly label for long names
    label="$t"
    if [[ ${#label} -gt $max_len ]]; then max_len=${#label}; fi
done
# add a little padding
WIDTH=$((max_len + 2))

# Pretty header for premium look
hr
printf '\033[1;37m[INFO]\033[0m    Installed Tools & Versions\033[0m'
hr
blank

# Render function with category title and tools
render_category() {
    title="$1"; shift
    tools=("$@")
    printf '\e[1;36m[INFO]\e[0m    %s\e[0m\n' "$title"
    for t in "${tools[@]}"; do
        label="$t:"
        # pad label to WIDTH
        printf " %b•%b %-${WIDTH}s " "$C_CYAN" "$C_RESET" "$label"
        # get version string (colored)
        get_version "$t"
        # newline
        echo
        # optional slow UX
        [[ "$SLOW_PRINT" > 0 ]] && sleep "$SLOW_PRINT"
    done
    blank
}

# ------------------- Print categories -------------------
render_category "Programming Languages" "${lang[@]}"
render_category "DevOps Infrastructure" "${devops[@]}"
render_category "Kubernetes Stack" "${kube[@]}"
render_category "Cloud Providers" "${cloud[@]}"
render_category "Security / DevSecOps" "${sec[@]}"
render_category "Build Test Chain" "${build[@]}"

# Network utilities availability (availability-only)
hr
printf '\e[1;37m[INFO]\e[0m    Network Utility Availability\e[0m\n'
for util in dig nslookup traceroute netcat nc iperf3 nmap curl wget; do
    printf " %b•%b %-${WIDTH}s " "$C_CYAN" "$C_RESET" "${util}:"
    if command -v "$util" >/dev/null 2>&1; then
        printf "%bAvailable%b\n" "$C_GREEN" "$C_RESET"
    else
        printf "%bMissing%b\n" "$C_RED" "$C_RESET"
    fi
    [[ "$SLOW_PRINT" > 0 ]] && sleep "$SLOW_PRINT"
done

hr
ok "Version scan complete"
blank

exit 0

# rust | maven | az # maybe due to sudo
# # Security / DevSecOps