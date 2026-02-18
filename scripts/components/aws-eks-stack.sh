#!/usr/bin/env bash
# ================================================================
# infra-bootstrap — AWS + EKS Tooling Stack
# Installs:
#   • AWS CLI v2
#   • eksctl
#   • aws-iam-authenticator
#   • kubelogin (OIDC auth for Kubernetes)
#
# Optional:
#   --auto-config  → Ask for AWS Keys + Validate using sts:get-caller-identity
# ================================================================

set -Eeuo pipefail
IFS=$'\n\t'
trap 'echo; echo "[ERR] Failed at line $LINENO"; exit 1' ERR

REPO_BASE="https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts"
source <(curl -fsSL "$REPO_BASE/lib/common.sh")

banner "AWS + EKS Tooling Stack"

# ----------------------------- CLI Flags -----------------------------
AUTO_CFG=false
[[ "${1:-}" == "--auto-config" ]] && AUTO_CFG=true

# -------------------------- Architecture Detect ----------------------
# Works on: amd64, x86_64, arm64, aarch64 — never unbound
ARCH_RAW=$(uname -m 2>/dev/null || echo "unknown")
case "$ARCH_RAW" in
    x86_64|amd64) ARCH="amd64" ;;
    arm64|aarch64) ARCH="arm64" ;;
    *) ARCH="unknown" ;;
esac

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
PLATFORM="${OS}_${ARCH}"

if [[ "$ARCH" == "unknown" ]]; then
    warn "Unknown architecture ($ARCH_RAW). Installer will still continue"
fi

# ---------------------------- Preflight ------------------------------
hr
info "Running preflight checks..."
if bash <(curl -fsSL "$REPO_BASE/system-checks/preflight.sh") >/dev/null 2>&1; then
    ok "Preflight passed."
else
    error "Preflight failed — aborting installation."
fi

# ---------------------- AWS CLI v2 Install --------------------------
hr
info "Installing AWS CLI v2..."

if aws --version &>/dev/null; then
    AWS_VER=$(aws --version | awk '{print $1}' | cut -d/ -f2)
    ok "AWS CLI already installed ($AWS_VER)"
else
    pkg="awscliv2.zip"
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-$ARCH.zip" -o "$pkg"
    unzip -qq "$pkg"
    sudo ./aws/install >/dev/null 2>&1 || sudo ./aws/install --update >/dev/null 2>&1
    rm -rf aws "$pkg"
    ok "AWS CLI v2 installed"
fi

# -------------------------- eksctl Install ---------------------------
hr
info "Installing eksctl..."
if eksctl version &>/dev/null; then
    ok "eksctl already installed ($(eksctl version))"
else
    curl -fsSL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_${ARCH}.tar.gz" -o eksctl.tgz
    tar -xzf eksctl.tgz
    sudo install -m 0755 eksctl /usr/local/bin/eksctl
    rm -f eksctl eksctl.tgz
    ok "eksctl installed"
fi

# ------------------- aws-iam-authenticator Install -------------------
hr
info "Installing aws-iam-authenticator..."
if command -v aws-iam-authenticator >/dev/null; then
    ok "aws-iam-authenticator already installed"
else
    curl -fsSL "https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/latest/download/aws-iam-authenticator_${ARCH}" \
        -o /tmp/aws-iam-authenticator
    sudo install -m 0755 /tmp/aws-iam-authenticator /usr/local/bin/aws-iam-authenticator
    rm -f /tmp/aws-iam-authenticator
    ok "aws-iam-authenticator installed"
fi

# -------------------------- kubelogin Install ------------------------
hr
info "Installing kubelogin..."
if command -v kubelogin >/dev/null; then
    ok "kubelogin already installed"
else
    curl -fsSL "https://github.com/int128/kubelogin/releases/latest/download/kubelogin_linux_${ARCH}.zip" -o kl.zip
    unzip -qq kl.zip -d /tmp/kubelogin
    sudo install -m 0755 /tmp/kubelogin/bin/linux_${ARCH}/kubelogin /usr/local/bin/kubelogin
    rm -rf kl.zip /tmp/kubelogin
    ok "kubelogin installed"
fi

# ================= Optional AWS Auto Configure ===================
if [[ "$AUTO_CFG" == true ]]; then
    hr
    info "AWS credential setup enabled (validation required)"

    exec </dev/tty
    for attempt in {1..3}; do
        read -p "AWS Access Key ID: " AK
        read -p "AWS Secret Access Key: " SK
        read -p "Default region (ap-south-1): " REG
        read -p "Output format [json/text/table]: " OUT

        # Temporary config (not writing to ~/.aws yet)
        mkdir -p /tmp/aws-test
        export AWS_SHARED_CREDENTIALS_FILE="/tmp/aws-test/creds"
        export AWS_CONFIG_FILE="/tmp/aws-test/config"

        aws configure set aws_access_key_id "$AK"
        aws configure set aws_secret_access_key "$SK"
        aws configure set region "$REG"
        aws configure set output "$OUT"

        if aws sts get-caller-identity >/dev/null 2>&1; then
            ok "Credentials validated — saving permanently"
            
            mkdir -p "$HOME/.aws"
            aws configure set aws_access_key_id "$AK"
            aws configure set aws_secret_access_key "$SK"
            aws configure set region "$REG"
            aws configure set output "$OUT"
            
            rm -rf /tmp/aws-test
            break
        else
            warn "Invalid credentials — try again ($attempt/3)"
        fi
    done

    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        warn "Credential setup skipped — could not validate"
    fi
else
    warn "Skipping AWS configuration (use --auto-config)"
fi

# ---------------------------- Final Output ----------------------------
AWS_VERSION=$(aws --version | awk '{print $1}' | cut -d/ -f2)
EKSCTL_VERSION=$(eksctl version | sed 's/v//')
IAM_RAW=$(aws-iam-authenticator version 2>/dev/null || echo "")
if [[ "$IAM_RAW" =~ ^\{ ]]; then
    IAM_VERSION=$(echo "$IAM_RAW" | jq -r '.Version' 2>/dev/null || echo "unknown")
else
    IAM_VERSION=$(echo "$IAM_RAW" | awk -F\" '/Version/{print $4}' | sed 's/v//' || echo "unknown")
fi
KUBELOGIN_V=$(kubelogin --version 2>/dev/null | awk '{print $3}' | sed 's/v//' || echo "unknown")

# ================= Version Output (pretty aligned) =================
PAD=26   # column alignment width

item_ver() {  # consistent formatted output
    printf " %b•%b %-*s %s\n" "$C_CYAN" "$C_RESET" "$PAD" "$1:" "$2"
}

# Safety → No unbound variable risk
AWS_VERSION="${AWS_VERSION:-unknown}"
EKSCTL_VERSION="${EKSCTL_VERSION:-unknown}"
IAM_VERSION="${IAM_VERSION:-unknown}"
KUBELOGIN_V="${KUBELOGIN_V:-unknown}"

hr
item_ver "AWS CLI"               "$AWS_VERSION"
item_ver "eksctl"                "$EKSCTL_VERSION"
item_ver "aws-iam-authenticator" "$IAM_VERSION"
item_ver "kubelogin"             "$KUBELOGIN_V"
hr
ok "AWS + EKS tooling ready"

exit 0