#!/usr/bin/env bash
# =====================================================================
# infra-bootstrap : Installed Tools & Version Audit (Enterprise Grade)
# Requirements:
#   • Runs universal preflight first
#   • Prints one tool per line, padded, versions only
#   • Missing → [ NOT INSTALLED ]
#   • Zero banner noise; professional formatting
# =====================================================================

set -Eeuo pipefail
IFS=$'\n\t'

# ================== Load shared common.sh ==================
COMMON_URL="https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/lib/common.sh"
tmp="$(mktemp)"
curl -fsSL "$COMMON_URL" -o "$tmp" || { echo "common.sh failed to load"; exit 1; }
# shellcheck disable=SC1090
source "$tmp"
rm -f "$tmp"

banner "Installed Tools & Versions"


# ================== PRE-FLIGHT ENFORCED ==================
PRE_URL="https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/system-checks/preflight.sh"

info "Preflight check running..."
if ! out=$(bash <(curl -fsSL "$PRE_URL") 2>&1); then
    error "Preflight failed — stopping version audit."
    printf "\nDetails:\n%s\n" "$out"
    exit 1
fi

ok "Preflight passed!"
blank

# ================== VERSION RESOLVER ==================
# Must return only version, no banners.


get_version() {
    tool="$1"
    ver=""

    # If tool is not compose → normal binary check applies
    if [[ "$tool" != "compose" ]]; then
        if ! command -v "$tool" >/dev/null 2>&1; then
            printf "%b[ NOT INSTALLED ]%b" "$C_RED" "$C_RESET"
            return
        fi
    fi

    case $tool in
        # ---- Programming ----
        python3)    ver=$(python3 -V 2>/dev/null | awk '{print $2}') ;;
        go)         ver=$(go version 2>/dev/null | awk '{print $3}' | cut -c3-) ;;
        node)       ver=$(node -v 2>/dev/null | cut -c2-) ;;
        ruby)       ver=$(ruby -v 2>/dev/null | awk '{print $2}') ;;
        rust)       ver=$(rustc -V 2>/dev/null | awk '{print $2}') ;;
        java)       ver=$(java -version 2>&1 | awk -F\" '/version/ {print $2}') ;;

        # ---- DevOps / Infra ----
        docker)     ver=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',') ;;
        compose)
            if docker compose version >/dev/null 2>&1; then
                ver=$(docker compose version | awk 'NR==1 {for(i=1;i<=NF;i++) if($i~/v?[0-9]+\.[0-9]+\.[0-9]/){gsub(/^v/,"",$i);print $i}}')
            elif command -v docker-compose >/dev/null 2>&1; then
                ver=$(docker-compose version | awk 'NR==1 {for(i=1;i<=NF;i++) if($i~/[0-9]+\.[0-9]+\.[0-9]/){print $i}}')
            elif [ -x /usr/lib/docker/cli-plugins/docker-compose ]; then
                ver=$(/usr/lib/docker/cli-plugins/docker-compose version | awk 'NR==1 {for(i=1;i<=NF;i++) if($i~/v?[0-9]+\.[0-9]+\.[0-9]/){gsub(/^v/,"",$i);print $i}}')
            elif [ -x "$HOME/.docker/cli-plugins/docker-compose" ]; then
                ver=$("$HOME/.docker/cli-plugins/docker-compose" version | awk 'NR==1 {for(i=1;i<=NF;i++) if($i~/v?[0-9]+\.[0-9]+\.[0-9]/){gsub(/^v/,"",$i);print $i}}')
            fi
        ;;
        containerd) ver=$(containerd --version 2>/dev/null | awk '{print $3}' | sed 's/^v//') ;;
        runc)       ver=$(runc --version 2>/dev/null | awk '{print $3}') ;;
        ansible)    ver=$(ansible --version 2>/dev/null | awk 'NR==1{gsub(/\]|\[/,"",$3); print $3}') ;;
        jenkins)    ver=$(jenkins --version 2>/dev/null | awk '{print $1}') ;;
        terraform)  ver=$(terraform version 2>/dev/null | awk 'NR==1{print $2}' | sed 's/v//') ;;
        packer)     ver=$(packer version 2>/dev/null | awk 'NR==1{print $2}') ;;
        vagrant)    ver=$(vagrant --version 2>/dev/null | awk '{print $2}') ;;
        podman)     ver=$(podman --version 2>/dev/null | awk '{print $3}') ;;
        buildah)    ver=$(buildah --version 2>/dev/null | awk '{print $3}') ;;

        # ---- Kubernetes Stack ----
        kubectl)    ver=$(kubectl version --client --output=json 2>/dev/null | jq -r .clientVersion.gitVersion | sed 's/v//') ;;
        k9s)        ver=$(k9s version --short 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1) ;;
        helm)       ver=$(helm version --short 2>/dev/null | cut -d'+' -f1 | sed 's/^v//') ;;
        eksctl)     ver=$(eksctl version 2>/dev/null | sed 's/v//') ;;
        kind)       ver=$(kind version 2>/dev/null | sed -n 's/^kind v//p' | awk '{print $1}') ;;
        crictl)     ver=$(crictl version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+') ;;
        etcdctl)    ver=$(etcdctl version 2>/dev/null | awk '/etcdctl/ {print $3}') ;;
        kustomize)  ver=$(kustomize version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+') ;;
        minikube)   ver=$(minikube version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+') ;;
        aws-iam-authenticator) ver=$(aws-iam-authenticator version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' ) ;;
        kubelogin)  ver=$(kubelogin --version 2>/dev/null | awk '{print $3}' | sed 's/v//' ) ;;


        # ---- Cloud Providers ----
        aws)        ver=$(aws --version 2>&1 | awk -F/ '{print $2}' | cut -d' ' -f1) ;;
        gcloud)     ver=$(gcloud version --format="value(core.version)" 2>/dev/null) ;;
        doctl)      ver=$(doctl version 2>/dev/null | awk '{print $2}') ;;
        azure|az)   ver=$(az version 2>/dev/null | jq -r '."azure-cli"' 2>/dev/null) ;;

        # ---- Security / DevSecOps ----
        trivy)      ver=$(trivy --version 2>/dev/null | awk 'NR==1{print $2}') ;;
        vault)      ver=$(vault version 2>/dev/null | awk '{print $2}') ;;
        lynis)      ver=$(lynis show version 2>/dev/null | awk '{print $3}') ;;
        falco)      ver=$(falco --version 2>/dev/null | awk '{print $3}') ;;
        bandit)     ver=$(bandit --version 2>&1 | awk '{print $2}') ;;
        snyk)       ver=$(snyk -v 2>/dev/null) ;;

        # ---- Build & Test Toolchain ----
        npm)           ver=$(npm -v 2>/dev/null) ;;
        pip)           ver=$(pip -V 2>/dev/null | awk '{print $2}') ;;
        pip3)          ver=$(pip3 -V 2>/dev/null | awk '{print $2}') ;;
        make)          ver=$(make -v 2>/dev/null | head -n1 | awk '{print $3}') ;;
        gcc)           ver=$(gcc -v 2>&1 | awk -F" " '/gcc version/ {print $3}') ;;
        g++)           ver=$(g++ -v 2>&1 | awk '/gcc version/ {print $3}') ;;
        cmake)         ver=$(cmake --version 2>/dev/null | head -n1 | awk '{print $3}') ;;
        pytest)        ver=$(pytest --version 2>/dev/null | awk '{print $2}') ;;
        maven)         ver=$(mvn -version 2>/dev/null | awk -F" " '/Apache Maven/ {print $3}') ;;
        gradle)        ver=$(gradle -v 2>/dev/null | awk '/Gradle/ {print $2}') ;;
        mkdocs)        ver=$(mkdocs --version 2>/dev/null | awk '{print $2}') ;;
        shellcheck)    ver=$(shellcheck --version 2>/dev/null | awk 'NR==1{print $2}') ;;
        yamllint)      ver=$(yamllint --version 2>/dev/null | awk '{print $2}') ;;
        golangci-lint) ver=$(golangci-lint version 2>/dev/null | awk '{print $4}') ;;
    esac

    if [[ -z "${ver:-}" ]]; then
        printf "%b[ NOT INSTALLED ]%b" "$C_RED" "$C_RESET"
    else
        printf "%b%-10s%b" "$C_GREEN" "$ver" "$C_RESET"
    fi
}

# ================== PRINT CATEGORIES ==================
render() {
    hr
    info "$1"
    shift
    for t in "$@"; do
        printf " %b•%b %-15s %s\n" "$C_CYAN" "$C_RESET" "${t}:" "$(get_version "$t")"
    done
}

render "Programming Languages"    python3 go node ruby rust java
render "DevOps & Infrastructure"  docker compose containerd runc ansible jenkins terraform packer vagrant podman buildah
render "Kubernetes Stack"         kubectl k9s helm eksctl kind crictl etcdctl kustomize minikube aws-iam-authenticator kubelogin
render "Cloud Providers"          aws gcloud doctl azure
render "Security / DevSecOps"     trivy vault lynis falco bandit snyk
render "Build & Test Chain"       npm pip pip3 make gcc g++ cmake pytest maven gradle mkdocs shellcheck yamllint golangci-lint

# ================== NETWORK UTILITIES (availability only) ==================
hr
info "Network Utility Availability"

for util in dig nslookup traceroute netcat nc iperf3 nmap curl wget; do
    if command -v "$util" >/dev/null 2>&1; then
        printf " %b•%b %-15s %bAvailable%b\n" \
            "$C_CYAN" "$C_RESET" "${util}:" "$C_GREEN" "$C_RESET"
    else
        printf " %b•%b %-15s %bMissing%b\n" \
            "$C_CYAN" "$C_RESET" "${util}:" "$C_RED" "$C_RESET"
    fi
done

hr
ok "Version scan complete"
blank

exit 0