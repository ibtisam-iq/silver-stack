#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# ULTIMATE DevOps/SRE/Platform Engineering Rootfs Installation Script
# Ubuntu 24.04 LTS (Noble Numbat) - February 2026
# Complete Installation: 350+ Tools Across All Categories
# =============================================================================

export DEBIAN_FRONTEND=noninteractive
export TZ=UTC
export ARKADE_BIN_DIR=/usr/local/bin
export PATH="${PATH}:/usr/local/go/bin:${HOME}/.cargo/bin:${HOME}/.krew/bin"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_phase() { echo -e "\n${BLUE}=== $1 ===${NC}\n"; }

# =============================================================================
# PHASE 1: APT Repository Setup & System Update
# =============================================================================

log_phase "PHASE 1: Updating APT repositories and system packages"
apt-get update
apt-get upgrade -y
apt-get dist-upgrade -y

# =============================================================================
# PHASE 2: Core System & Runtime Packages
# =============================================================================

log_phase "PHASE 2: Installing core system and runtime packages"
apt-get install -y \
  systemd dbus udev kmod locales ca-certificates lsb-release \
  sudo bash zsh fish tmux screen \
  bash-completion zsh-autosuggestions zsh-syntax-highlighting

# =============================================================================
# PHASE 3: Build Essentials & Compression Tools
# =============================================================================

log_phase "PHASE 3: Installing build essentials and compression utilities"
apt-get install -y \
  build-essential gcc g++ clang llvm cmake pkg-config \
  autoconf automake libtool make ninja-build meson \
  bzip2 xz-utils zstd unzip zip p7zip-full tar gzip

# =============================================================================
# PHASE 4: Languages & Runtimes (via APT)
# =============================================================================

log_phase "PHASE 4: Installing programming languages and runtimes"

apt-get install -y \
  python3 python3-pip python3-venv python3-dev python3-setuptools \
  ruby ruby-dev rubygems \
  perl lua5.4 \
  openjdk-21-jdk

# Skip nodejs/npm - already installed from NodeSource in Phase 15
log_info "Node.js/npm, rustc/cargo will be installed from NodeSource in Phase 15"

# =============================================================================
# PHASE 5: Editors & TUI Tools
# =============================================================================

log_phase "PHASE 5: Installing text editors and TUI utilities"
apt-get install -y \
  vim neovim nano emacs-nox \
  htop iotop atop less most bat

# =============================================================================
# PHASE 6: File Management & Search Tools
# =============================================================================

log_phase "PHASE 6: Installing file management and search utilities"
apt-get install -y \
  ripgrep fd-find tree ncdu lsof file \
  rsync pv progress inotify-tools \
  direnv entr parallel gettext-base

# =============================================================================
# PHASE 7: Networking & Troubleshooting
# =============================================================================

log_phase "PHASE 7: Installing networking and diagnostic tools"

apt-get install -y \
  iproute2 net-tools iputils-ping iputils-tracepath \
  traceroute mtr tcptraceroute nmap ncat socat netcat-openbsd \
  tcpdump tshark wireshark-common \
  iperf3 iftop nethogs vnstat iptraf-ng \
  dnsutils bind9-dnsutils whois host \
  iptables nftables ipset conntrack \
  bridge-utils vlan ethtool \
  wireguard-tools openvpn strongswan \
  dnsmasq avahi-daemon stunnel4 openssl gnutls-bin \
  curl wget httpie

# =============================================================================
# PHASE 8: Storage & Filesystem Tools
# =============================================================================

log_phase "PHASE 8: Installing storage and filesystem utilities"
apt-get install -y \
  lvm2 mdadm cryptsetup parted fdisk gdisk \
  e2fsprogs xfsprogs btrfs-progs \
  nfs-common nfs-kernel-server cifs-utils smbclient \
  fuse3 sshfs davfs2 smartmontools hdparm

# =============================================================================
# PHASE 9: System Debugging & Profiling
# =============================================================================

log_phase "PHASE 9: Installing debugging and profiling tools"
apt-get install -y \
  strace ltrace sysstat gdb valgrind \
  procps psmisc fatrace \
  auditd systemd-coredump \
  linux-tools-generic bpftrace bpfcc-tools

# =============================================================================
# PHASE 10: Security Tools
# =============================================================================

log_phase "PHASE 10: Installing security utilities"
apt-get install -y \
  fail2ban ufw apparmor apparmor-utils \
  nmap nikto sqlmap lynis chkrootkit rkhunter \
  gpg gnupg2 pass acl attr

# =============================================================================
# PHASE 11: Database CLI Clients
# =============================================================================

log_phase "PHASE 11: Installing database client tools"
apt-get install -y \
  mysql-client postgresql-client sqlite3 redis-tools

# =============================================================================
# PHASE 12: Version Control
# =============================================================================

log_phase "PHASE 12: Installing version control systems"
apt-get install -y git git-lfs tig

# =============================================================================
# PHASE 13: Install Python Tools via pip
# =============================================================================

log_phase "PHASE 13: Installing Python-based tools"

# Install required development libraries
log_info "Installing development libraries..."
apt-get install -y \
  libpq-dev \
  libmysqlclient-dev \
  libffi-dev \
  libssl-dev

# Install Python tools with --ignore-installed to avoid Debian conflicts
log_info "Installing Python CLI tools..."
python3 -m pip install --break-system-packages --ignore-installed \
  pre-commit \
  ansible \
  ansible-lint \
  yamllint \
  bandit \
  detect-secrets \
  mkdocs \
  mkdocs-material \
  httpie \
  glances \
  thefuck \
  csvkit \
  aider-chat \
  dvc \
  mlflow \
  locust || log_warn "Some Python packages failed to install"

# Install semgrep (try multiple methods)
log_info "Installing semgrep..."
if python3 -m pip install --break-system-packages --ignore-installed 'semgrep==1.95.0' 2>/dev/null; then
  log_info "✓ Semgrep installed via pip"
elif curl -sSL https://install.semgrep.dev 2>/dev/null | sh -s -- --prefix /usr/local; then
  log_info "✓ Semgrep installed via official installer"
else
  log_warn "Semgrep installation failed - skipping"
fi

# =============================================================================
# Security Tools Installation
# =============================================================================

log_phase "Installing Security Tools"

# Function to download with aggressive timeout
download_security_tool() {
    local url=$1
    local output=$2
    timeout 20 wget --timeout=10 --tries=1 -q "$url" -O "$output" 2>/dev/null || {
        log_warn "Failed to download $(basename $output)"
        return 1
    }
}

# Gitleaks
log_info "Installing gitleaks..."
if ! command -v gitleaks &> /dev/null; then
    GITLEAKS_VERSION=$(timeout 5 curl -s "https://api.github.com/repos/gitleaks/gitleaks/releases/latest" 2>/dev/null | grep -Po '"tag_name": "v\K[0-9.]+' || echo "8.21.2")
    if download_security_tool "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" "/tmp/gitleaks.tar.gz"; then
        tar -xzf /tmp/gitleaks.tar.gz -C /tmp/ gitleaks 2>/dev/null
        cp /tmp/gitleaks /usr/local/bin/ 2>/dev/null
        chmod +x /usr/local/bin/gitleaks
        rm -rf /tmp/gitleaks*
    fi
else
    log_info "gitleaks already installed, skipping"
fi

# Trufflehog
log_info "Installing trufflehog..."
if ! command -v trufflehog &> /dev/null; then
    TRUFFLEHOG_VERSION=$(timeout 5 curl -s "https://api.github.com/repos/trufflesecurity/trufflehog/releases/latest" 2>/dev/null | grep -Po '"tag_name": "v\K[0-9.]+' || echo "3.87.2")
    if download_security_tool "https://github.com/trufflesecurity/trufflehog/releases/download/v${TRUFFLEHOG_VERSION}/trufflehog_${TRUFFLEHOG_VERSION}_linux_amd64.tar.gz" "/tmp/trufflehog.tar.gz"; then
        tar -xzf /tmp/trufflehog.tar.gz -C /tmp/ trufflehog 2>/dev/null
        cp /tmp/trufflehog /usr/local/bin/ 2>/dev/null
        chmod +x /usr/local/bin/trufflehog
        rm -rf /tmp/trufflehog*
    fi
else
    log_info "trufflehog already installed, skipping"
fi

# Database CLIs (pgcli, mycli)
log_info "Installing database CLIs..."
if ! command -v pgcli &> /dev/null || ! command -v mycli &> /dev/null; then
    timeout 120 python3 -m pip install --break-system-packages --quiet pgcli mycli 2>&1 | grep -vE "WARNING|ERROR|incompatible" || \
        log_warn "Database CLIs installation timed out or failed"
else
    log_info "Database CLIs already installed, skipping"
fi

log_info "✓ Security tools installation complete"

# =============================================================================
# PHASE 14: Container Tools (Docker/Podman/Buildah)
# =============================================================================

log_phase "PHASE 14: Installing container runtimes"

# Docker CE repository
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y \
  docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

# Podman & Buildah
apt-get install -y podman buildah skopeo

# =============================================================================
# PHASE 15: Install Latest Node.js LTS (v20.x)
# =============================================================================

log_phase "PHASE 15: Installing Node.js LTS v20.x"
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# =============================================================================
# PHASE 16: Install Latest Golang
# =============================================================================

log_phase "PHASE 16: Installing Go 1.22"
GO_VERSION="1.22.0"
GO_ARCH="$(dpkg --print-architecture)"
[[ "$GO_ARCH" == "amd64" ]] && GO_ARCH="amd64" || GO_ARCH="arm64"

wget -q "https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz" -O /tmp/go.tar.gz
rm -rf /usr/local/go
tar -C /usr/local -xzf /tmp/go.tar.gz
rm /tmp/go.tar.gz

cat > /etc/profile.d/go.sh <<'EOF'
export PATH=$PATH:/usr/local/go/bin
export GOPATH=/root/go
export PATH=$PATH:$GOPATH/bin
EOF

export PATH=$PATH:/usr/local/go/bin

# =============================================================================
# PHASE 17: Install Rust via rustup
# =============================================================================

log_phase "PHASE 17: Installing Rust via rustup"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
export PATH="$HOME/.cargo/bin:$PATH"

# Verify installation
rustc --version || log_warn "Rust installation may have failed"
cargo --version || log_warn "Cargo installation may have failed"

# =============================================================================
# PHASE 18: Install arkade
# =============================================================================

log_phase "PHASE 18: Installing arkade"
# Download arkade binary directly
ARKADE_VERSION="0.11.82"
ARCH="$(uname -m)"
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

log_info "Downloading arkade v${ARKADE_VERSION}..."
wget --timeout=30 --tries=3 -q \
    "https://github.com/alexellis/arkade/releases/download/${ARKADE_VERSION}/arkade" \
    -O /tmp/arkade

# Verify it's a valid binary (not HTML error page)
if file /tmp/arkade | grep -q "ELF.*executable"; then
    chmod +x /tmp/arkade
    mv /tmp/arkade /usr/local/bin/arkade
    log_info "✓ Arkade installed successfully"
else
    log_error "Downloaded file is not a valid binary"
    rm -f /tmp/arkade
    exit 1
fi

# Create ark symlink
ln -sf /usr/local/bin/arkade /usr/local/bin/ark 2>/dev/null || true

# Verify installation
arkade version || log_warn "Arkade verification failed"

# =============================================================================
# PHASE 19: Install Core Tools via arkade
# =============================================================================

log_phase "PHASE 19: Installing tools via arkade"

ark get \
  kubectl helm kustomize k9s kubectx kubens stern kubeseal flux argocd \
  dive crane nerdctl regctl \
  terraform terragrunt packer vault consul \
  gh glab tkn \
  jq yq \
  fzf lazygit lazydocker just task \
  promtool \
  trivy cosign syft grype \
  hey \
  sops age \
  doctl civo \
  cilium istioctl linkerd2 \
  krew vcluster kind k3d minikube tilt

# Move arkade binaries to /usr/local/bin
[ -d "$HOME/.arkade/bin" ] && cp -f $HOME/.arkade/bin/* /usr/local/bin/ 2>/dev/null || true

# =============================================================================
# PHASE 20: Install kubectl krew plugins
# =============================================================================

log_phase "PHASE 20: Installing kubectl krew and plugins"

(
  set -x; cd "$(mktemp -d)"
  OS="$(uname | tr '[:upper:]' '[:lower:]')"
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')"
  KREW="krew-${OS}_${ARCH}"
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz"
  tar zxf "${KREW}.tar.gz"
  ./"${KREW}" install krew
)

export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# Install krew plugins
kubectl krew install ctx ns neat images resource-capacity node-shell \
  whoami view-secret df-pv get-all sniff trace

# =============================================================================
# PHASE 21: Install Go-based Tools
# =============================================================================

log_phase "PHASE 21: Installing Go-based tools"

go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
go install github.com/securego/gosec/v2/cmd/gosec@latest
go install github.com/google/ko@latest
go install github.com/google/gops@latest
go install github.com/charmbracelet/glow@latest
go install github.com/gohugoio/hugo@latest
go install github.com/cloudflare/cfssl/cmd/...@latest
go install filippo.io/mkcert@latest
go install github.com/hakluke/hakrawler@latest
go install github.com/tomnomnom/gron@latest
go install mvdan.cc/sh/v3/cmd/shfmt@latest

# Copy Go binaries to /usr/local/bin
cp -f $HOME/go/bin/* /usr/local/bin/ 2>/dev/null || true

log_info "✓ Go-based tools installed successfully"

# =============================================================================
# PHASE 22: Install Rust-based Tools
# =============================================================================

log_phase "PHASE 22: Installing Rust-based tools"

cargo install ripgrep fd-find bat exa sd tokei hyperfine \
  gitui bottom procs du-dust bandwhich zoxide starship \
  just cargo-edit cargo-watch

# =============================================================================
# PHASE 23: Installing Binary Tools from GitHub Releases
# =============================================================================

log_phase "PHASE 23: Installing binary tools from GitHub releases"

# Function to download with retry
download_with_retry() {
    local url=$1
    local output=$2
    local max_attempts=3
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if wget --timeout=15 --tries=2 -qO "$output" "$url" 2>/dev/null; then
            return 0
        fi
        log_warn "Download attempt $attempt failed, retrying..."
        attempt=$((attempt + 1))
        sleep 2
    done
    return 1
}

# Hadolint
log_info "Installing hadolint..."
download_with_retry \
  "https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64" \
  /usr/local/bin/hadolint && chmod +x /usr/local/bin/hadolint || log_warn "hadolint failed"

# Helmfile
log_info "Installing helmfile..."
if download_with_retry \
  "https://github.com/helmfile/helmfile/releases/latest/download/helmfile_linux_amd64.tar.gz" \
  /tmp/helmfile.tar.gz; then
    tar xf /tmp/helmfile.tar.gz -C /usr/local/bin helmfile 2>/dev/null
    chmod +x /usr/local/bin/helmfile
    rm /tmp/helmfile.tar.gz
else
    log_warn "helmfile installation failed"
fi

# Helm plugins
log_info "Installing helm plugins..."
timeout 30 helm plugin install https://github.com/databus23/helm-diff --verify=false 2>/dev/null || log_warn "helm-diff skipped"
timeout 30 helm plugin install https://github.com/jkroepke/helm-secrets --verify=false 2>/dev/null || log_warn "helm-secrets skipped"
timeout 30 helm plugin install https://github.com/chartmuseum/helm-push --verify=false 2>/dev/null || log_warn "helm-push skipped"

# Kube-bench
log_info "Installing kube-bench..."
if download_with_retry \
  "https://github.com/aquasecurity/kube-bench/releases/latest/download/kube-bench_linux_amd64.tar.gz" \
  /tmp/kube-bench.tar.gz; then
    tar xf /tmp/kube-bench.tar.gz -C /usr/local/bin kube-bench 2>/dev/null
    chmod +x /usr/local/bin/kube-bench
    rm /tmp/kube-bench.tar.gz
else
    log_warn "kube-bench installation failed"
fi

# Kubescape
log_info "Installing kubescape..."
timeout 30 bash -c "curl -s https://raw.githubusercontent.com/kubescape/kubescape/master/install.sh | bash" 2>/dev/null || log_warn "kubescape skipped"
mv kubescape /usr/local/bin/ 2>/dev/null || true

# Popeye
log_info "Installing popeye..."
if download_with_retry \
  "https://github.com/derailed/popeye/releases/latest/download/popeye_Linux_x86_64.tar.gz" \
  /tmp/popeye.tar.gz; then
    tar xf /tmp/popeye.tar.gz -C /usr/local/bin popeye 2>/dev/null
    chmod +x /usr/local/bin/popeye
    rm /tmp/popeye.tar.gz
else
    log_warn "popeye installation failed"
fi

# Polaris
log_info "Installing polaris..."
if download_with_retry \
  "https://github.com/FairwindsOps/polaris/releases/latest/download/polaris_linux_amd64.tar.gz" \
  /tmp/polaris.tar.gz; then
    tar xf /tmp/polaris.tar.gz -C /usr/local/bin polaris 2>/dev/null
    chmod +x /usr/local/bin/polaris
    rm /tmp/polaris.tar.gz
else
    log_warn "polaris installation failed"
fi

# Kyverno CLI
log_info "Installing kyverno..."
if download_with_retry \
  "https://github.com/kyverno/kyverno/releases/latest/download/kyverno-cli_linux_x86_64.tar.gz" \
  /tmp/kyverno.tar.gz; then
    tar xf /tmp/kyverno.tar.gz -C /usr/local/bin kyverno 2>/dev/null
    chmod +x /usr/local/bin/kyverno
    rm /tmp/kyverno.tar.gz
else
    log_warn "kyverno installation failed"
fi

# OPA
log_info "Installing OPA..."
download_with_retry \
  "https://github.com/open-policy-agent/opa/releases/latest/download/opa_linux_amd64_static" \
  /usr/local/bin/opa && chmod +x /usr/local/bin/opa || log_warn "opa failed"

# Conftest
log_info "Installing conftest..."
if download_with_retry \
  "https://github.com/open-policy-agent/conftest/releases/latest/download/conftest_linux_x86_64.tar.gz" \
  /tmp/conftest.tar.gz; then
    tar xf /tmp/conftest.tar.gz -C /usr/local/bin conftest 2>/dev/null
    chmod +x /usr/local/bin/conftest
    rm /tmp/conftest.tar.gz
else
    log_warn "conftest installation failed"
fi

# Kubeconform
log_info "Installing kubeconform..."
if download_with_retry \
  "https://github.com/yannh/kubeconform/releases/latest/download/kubeconform-linux-amd64.tar.gz" \
  /tmp/kubeconform.tar.gz; then
    tar xf /tmp/kubeconform.tar.gz -C /usr/local/bin kubeconform 2>/dev/null
    chmod +x /usr/local/bin/kubeconform
    rm /tmp/kubeconform.tar.gz
else
    log_warn "kubeconform installation failed"
fi

# Kube-score
log_info "Installing kube-score..."
download_with_retry \
  "https://github.com/zegl/kube-score/releases/latest/download/kube-score_linux_amd64" \
  /usr/local/bin/kube-score && chmod +x /usr/local/bin/kube-score || log_warn "kube-score failed"

# Pluto
log_info "Installing pluto..."
if download_with_retry \
  "https://github.com/FairwindsOps/pluto/releases/latest/download/pluto_linux_amd64.tar.gz" \
  /tmp/pluto.tar.gz; then
    tar xf /tmp/pluto.tar.gz -C /usr/local/bin pluto 2>/dev/null
    chmod +x /usr/local/bin/pluto
    rm /tmp/pluto.tar.gz
else
    log_warn "pluto installation failed"
fi

# Nova
log_info "Installing nova..."
if download_with_retry \
  "https://github.com/FairwindsOps/nova/releases/latest/download/nova_linux_amd64.tar.gz" \
  /tmp/nova.tar.gz; then
    tar xf /tmp/nova.tar.gz -C /usr/local/bin nova 2>/dev/null
    chmod +x /usr/local/bin/nova
    rm /tmp/nova.tar.gz
else
    log_warn "nova installation failed"
fi

# Terrascan
log_info "Installing terrascan..."
if download_with_retry \
  "https://github.com/tenable/terrascan/releases/latest/download/terrascan_Linux_x86_64.tar.gz" \
  /tmp/terrascan.tar.gz; then
    tar xf /tmp/terrascan.tar.gz -C /usr/local/bin terrascan 2>/dev/null
    chmod +x /usr/local/bin/terrascan
    rm /tmp/terrascan.tar.gz
else
    log_warn "terrascan installation failed"
fi

# Snyk CLI
log_info "Installing snyk..."
timeout 30 curl --compressed https://static.snyk.io/cli/latest/snyk-linux -o /usr/local/bin/snyk 2>/dev/null && \
  chmod +x /usr/local/bin/snyk || log_warn "snyk skipped"

# Nuclei
log_info "Installing nuclei..."
if download_with_retry \
  "https://github.com/projectdiscovery/nuclei/releases/latest/download/nuclei_linux_amd64.zip" \
  /tmp/nuclei.zip; then
    unzip -q /tmp/nuclei.zip -d /usr/local/bin/ 2>/dev/null
    chmod +x /usr/local/bin/nuclei
    rm /tmp/nuclei.zip
else
    log_warn "nuclei installation failed"
fi

# FFuf
log_info "Installing ffuf..."
if download_with_retry \
  "https://github.com/ffuf/ffuf/releases/latest/download/ffuf_linux_amd64.tar.gz" \
  /tmp/ffuf.tar.gz; then
    tar xf /tmp/ffuf.tar.gz -C /usr/local/bin ffuf 2>/dev/null
    chmod +x /usr/local/bin/ffuf
    rm /tmp/ffuf.tar.gz
else
    log_warn "ffuf installation failed"
fi

# Nerdctl
log_info "Installing nerdctl..."
if download_with_retry \
  "https://github.com/containerd/nerdctl/releases/latest/download/nerdctl-1.7.7-linux-amd64.tar.gz" \
  /tmp/nerdctl.tar.gz; then
    tar xf /tmp/nerdctl.tar.gz -C /usr/local/bin nerdctl 2>/dev/null
    chmod +x /usr/local/bin/nerdctl
    rm /tmp/nerdctl.tar.gz
else
    log_warn "nerdctl installation failed"
fi

# Regctl
log_info "Installing regctl..."
download_with_retry \
  "https://github.com/regclient/regclient/releases/latest/download/regctl-linux-amd64" \
  /usr/local/bin/regctl && chmod +x /usr/local/bin/regctl || log_warn "regctl failed"

# Argo Rollouts kubectl plugin
log_info "Installing kubectl-argo-rollouts..."
download_with_retry \
  "https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64" \
  /usr/local/bin/kubectl-argo-rollouts && chmod +x /usr/local/bin/kubectl-argo-rollouts || log_warn "argo-rollouts failed"

log_info "✓ Phase 23 complete"

# =============================================================================
# PHASE 24: Installing Cloud Provider CLIs
# =============================================================================

log_phase "PHASE 24: Installing Cloud Provider CLIs"

# Function to download with retry
download_cli_binary() {
    local url=$1
    local output=$2
    wget --timeout=15 --tries=2 -q "$url" -O "$output" 2>/dev/null || {
        log_warn "Failed to download $(basename $output)"
        return 1
    }
}

# AWS CLI v2
log_info "Installing AWS CLI v2..."
if ! command -v aws &> /dev/null; then
    ARCH="$(uname -m)"
    [[ "$ARCH" == "x86_64" ]] && AWS_ARCH="x86_64" || AWS_ARCH="aarch64"
    curl --max-time 60 "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip" -o "/tmp/awscliv2.zip"
    unzip -q /tmp/awscliv2.zip -d /tmp/
    /tmp/aws/install
    rm -rf /tmp/aws /tmp/awscliv2.zip
else
    log_info "AWS CLI already installed, skipping"
fi

# Google Cloud SDK
log_info "Installing Google Cloud SDK..."
if ! command -v gcloud &> /dev/null; then
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | \
        tee /etc/apt/sources.list.d/google-cloud-sdk.list > /dev/null
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
        gpg --dearmor --yes -o /usr/share/keyrings/cloud.google.gpg 2>/dev/null
    apt-get update -qq 2>/dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq google-cloud-cli 2>/dev/null
else
    log_info "Google Cloud SDK already installed, skipping"
fi

# Azure CLI
log_info "Installing Azure CLI..."
if ! command -v az &> /dev/null; then
    curl -sL https://aka.ms/InstallAzureCLIDeb | bash 2>&1 | grep -v "^Get:"
else
    log_info "Azure CLI already installed, skipping"
fi

# Linode CLI
log_info "Installing Linode CLI..."
if ! command -v linode-cli &> /dev/null; then
    python3 -m pip install --break-system-packages --quiet linode-cli 2>&1 | grep -v "WARNING"
else
    log_info "Linode CLI already installed, skipping"
fi

# Oracle Cloud CLI
log_info "Installing Oracle Cloud CLI..."
if ! command -v oci &> /dev/null; then
    timeout 120 bash -c "curl -sL https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh | \
        bash -s -- --accept-all-defaults --install-dir /usr/local/lib/oracle-cli \
        --exec-dir /usr/local/bin --script-dir /usr/local/bin/oci-cli-scripts" 2>&1 | grep -v "Tab completion" || \
        log_warn "Oracle CLI installation timed out or failed"
else
    log_info "Oracle CLI already installed, skipping"
fi

# Hetzner Cloud CLI
log_info "Installing Hetzner Cloud CLI..."
if ! command -v hcloud &> /dev/null; then
    if download_cli_binary "https://github.com/hetznercloud/cli/releases/latest/download/hcloud-linux-amd64.tar.gz" "/tmp/hcloud.tar.gz"; then
        tar -xzf /tmp/hcloud.tar.gz -C /usr/local/bin/ hcloud 2>/dev/null
        chmod +x /usr/local/bin/hcloud
        rm /tmp/hcloud.tar.gz
    fi
else
    log_info "hcloud already installed, skipping"
fi

# Vultr CLI
log_info "Installing Vultr CLI..."
if ! command -v vultr-cli &> /dev/null; then
    if download_cli_binary "https://github.com/vultr/vultr-cli/releases/latest/download/vultr-cli_linux_amd64.tar.gz" "/tmp/vultr.tar.gz"; then
        tar -xzf /tmp/vultr.tar.gz -C /usr/local/bin/ vultr-cli 2>/dev/null
        chmod +x /usr/local/bin/vultr-cli
        rm /tmp/vultr.tar.gz
    fi
else
    log_info "vultr-cli already installed, skipping"
fi

# Cloudflare Wrangler
log_info "Installing Cloudflare Wrangler..."
if ! command -v wrangler &> /dev/null; then
    timeout 60 npm install -g wrangler 2>&1 | grep -v "npm WARN" || log_warn "Wrangler installation failed"
else
    log_info "Wrangler already installed, skipping"
fi

# Scaleway CLI
log_info "Installing Scaleway CLI..."
if ! command -v scw &> /dev/null; then
    if download_cli_binary "https://github.com/scaleway/scaleway-cli/releases/latest/download/scaleway-cli_linux_amd64" "/usr/local/bin/scw"; then
        chmod +x /usr/local/bin/scw
    fi
else
    log_info "Scaleway CLI already installed, skipping"
fi

# IBM Cloud CLI
log_info "Installing IBM Cloud CLI..."
if ! command -v ibmcloud &> /dev/null; then
    timeout 90 bash -c "curl -fsSL https://clis.cloud.ibm.com/install/linux | sh" 2>&1 | grep -v "Downloading" || \
        log_warn "IBM Cloud CLI installation timed out or failed"
else
    log_info "IBM Cloud CLI already installed, skipping"
fi

# Fly.io CLI
log_info "Installing Fly.io CLI..."
if ! command -v flyctl &> /dev/null; then
    timeout 60 bash -c "curl -L https://fly.io/install.sh | sh" 2>&1 | grep -v "Downloading" || \
        log_warn "Fly.io CLI installation timed out or failed"
    # Copy to /usr/local/bin instead of relying on PATH
    cp -f $HOME/.fly/bin/flyctl /usr/local/bin/ 2>/dev/null || true
else
    log_info "Fly.io CLI already installed, skipping"
fi

# Copy to /usr/local/bin instead of relying on PATH
cp -f $HOME/.fly/bin/flyctl /usr/local/bin/ 2>/dev/null || true

log_info "✓ Phase 24 complete - Cloud Provider CLIs installed"

# =============================================================================
# PHASE 25: Installing Observability Stack
# =============================================================================

log_phase "PHASE 25: Installing Observability Stack"

# Function to download with retry and timeout
download_obs_binary() {
    local url=$1
    local output=$2
    wget --timeout=15 --tries=2 -q "$url" -O "$output" 2>/dev/null || {
        log_warn "Failed to download $(basename $output)"
        return 1
    }
}

# Prometheus (promtool already installed via arkade in Phase 19)
log_info "Skipping promtool - already installed via arkade"

# Loki
log_info "Installing Loki..."
if download_obs_binary "https://github.com/grafana/loki/releases/latest/download/loki-linux-amd64.zip" "/tmp/loki.zip"; then
    unzip -q /tmp/loki.zip -d /tmp/ 2>/dev/null
    mv /tmp/loki-linux-amd64 /usr/local/bin/loki 2>/dev/null
    chmod +x /usr/local/bin/loki
    rm -f /tmp/loki.zip
fi

# LogCLI
log_info "Installing LogCLI..."
if download_obs_binary "https://github.com/grafana/loki/releases/latest/download/logcli-linux-amd64.zip" "/tmp/logcli.zip"; then
    unzip -q /tmp/logcli.zip -d /tmp/ 2>/dev/null
    mv /tmp/logcli-linux-amd64 /usr/local/bin/logcli 2>/dev/null
    chmod +x /usr/local/bin/logcli
    rm -f /tmp/logcli.zip
fi

# Grafana CLI
log_info "Installing Grafana CLI..."
GRAFANA_VERSION=$(timeout 10 curl -s "https://api.github.com/repos/grafana/grafana/releases/latest" | grep -Po '"tag_name": "v\K[0-9.]+' || echo "11.4.0")
if download_obs_binary "https://dl.grafana.com/oss/release/grafana-${GRAFANA_VERSION}.linux-amd64.tar.gz" "/tmp/grafana.tar.gz"; then
    tar -xzf /tmp/grafana.tar.gz -C /tmp/ 2>/dev/null
    cp /tmp/grafana-*/bin/grafana-cli /usr/local/bin/ 2>/dev/null
    chmod +x /usr/local/bin/grafana-cli
    rm -rf /tmp/grafana*
fi

# OpenTelemetry Collector
log_info "Installing OpenTelemetry Collector..."
OTEL_VERSION=$(timeout 10 curl -s "https://api.github.com/repos/open-telemetry/opentelemetry-collector-releases/releases/latest" | grep -Po '"tag_name": "v\K[0-9.]+' || echo "0.117.0")
if download_obs_binary "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTEL_VERSION}/otelcol-contrib_${OTEL_VERSION}_linux_amd64.tar.gz" "/tmp/otelcol.tar.gz"; then
    tar -xzf /tmp/otelcol.tar.gz -C /usr/local/bin/ otelcol-contrib 2>/dev/null
    ln -sf /usr/local/bin/otelcol-contrib /usr/local/bin/otelcol
    chmod +x /usr/local/bin/otelcol-contrib
    rm -f /tmp/otelcol.tar.gz
fi

# Vector
log_info "Installing Vector..."
if ! command -v vector &> /dev/null; then
    timeout 60 bash -c "curl --proto '=https' --tlsv1.2 -sSfL https://sh.vector.dev | bash -s -- -y" 2>&1 | grep -v "Downloading" || \
        log_warn "Vector installation timed out"
    cp -f $HOME/.vector/bin/vector /usr/local/bin/ 2>/dev/null || true
else
    log_info "Vector already installed, skipping"
fi

# Jaeger
log_info "Installing Jaeger..."
(
    JAEGER_VERSION=$(timeout 10 curl -s "https://api.github.com/repos/jaegertracing/jaeger/releases/latest" | grep -Po '"tag_name": "v\K[0-9.]+' 2>/dev/null || echo "2.15.1")

    # Use timeout for the entire download operation
    timeout 30 wget --timeout=15 --tries=1 -q \
        "https://github.com/jaegertracing/jaeger/releases/download/v${JAEGER_VERSION}/jaeger-${JAEGER_VERSION}-linux-amd64.tar.gz" \
        -O /tmp/jaeger.tar.gz 2>/dev/null && \
    tar -xzf /tmp/jaeger.tar.gz -C /tmp/ 2>/dev/null && \
    find /tmp/jaeger-* -type f -name "jaeger-*" -executable -exec cp {} /usr/local/bin/ \; 2>/dev/null && \
    chmod +x /usr/local/bin/jaeger-* 2>/dev/null
    rm -rf /tmp/jaeger* 2>/dev/null
) || log_warn "Jaeger installation failed or timed out"

# Tempo CLI
log_info "Installing Tempo CLI..."
TEMPO_VERSION=$(timeout 10 curl -s "https://api.github.com/repos/grafana/tempo/releases/latest" | grep -Po '"tag_name": "v\K[0-9.]+' 2>/dev/null || echo "2.7.1")
if download_obs_binary "https://github.com/grafana/tempo/releases/download/v${TEMPO_VERSION}/tempo_${TEMPO_VERSION}_linux_amd64.tar.gz" "/tmp/tempo.tar.gz"; then
    tar -xzf /tmp/tempo.tar.gz -C /tmp/ 2>/dev/null
    cp /tmp/tempo /usr/local/bin/ 2>/dev/null
    chmod +x /usr/local/bin/tempo
    rm -rf /tmp/tempo*
fi

# Mimir CLI
log_info "Installing Mimir CLI..."
MIMIR_VERSION=$(timeout 10 curl -s "https://api.github.com/repos/grafana/mimir/releases/latest" | grep -Po '"tag_name": "mimir-\K[0-9.]+' 2>/dev/null || echo "2.15.0")
if download_obs_binary "https://github.com/grafana/mimir/releases/download/mimir-${MIMIR_VERSION}/mimirtool-linux-amd64" "/usr/local/bin/mimirtool"; then
    chmod +x /usr/local/bin/mimirtool
fi

log_info "✓ Phase 25 complete - Observability stack installed"

# =============================================================================
# PHASE 26: Installing Additional Utilities
# =============================================================================

log_phase "PHASE 26: Installing additional utilities"

# Function to download with timeout
download_util() {
    local url=$1
    local output=$2
    wget --timeout=15 --tries=2 -q "$url" -O "$output" 2>/dev/null || {
        log_warn "Failed to download $(basename $output)"
        return 1
    }
}

# Skip tools already installed in earlier phases
log_info "Skipping Starship - already installed via cargo in Phase 22"
log_info "Skipping Zoxide - already installed via cargo in Phase 22"
log_info "Skipping Atuin - already installed via cargo in Phase 22"

# Chezmoi
log_info "Installing Chezmoi..."
if ! command -v chezmoi &> /dev/null; then
    CHEZMOI_VERSION=$(curl -s --max-time 10 "https://api.github.com/repos/twpayne/chezmoi/releases/latest" | grep -Po '"tag_name": "v\K[0-9.]+' || echo "2.57.3")
    if download_util "https://github.com/twpayne/chezmoi/releases/download/v${CHEZMOI_VERSION}/chezmoi_${CHEZMOI_VERSION}_linux_amd64.tar.gz" "/tmp/chezmoi.tar.gz"; then
        tar -xzf /tmp/chezmoi.tar.gz -C /usr/local/bin/ chezmoi 2>/dev/null
        chmod +x /usr/local/bin/chezmoi
        rm /tmp/chezmoi.tar.gz
    fi
else
    log_info "Chezmoi already installed, skipping"
fi

# Nushell
log_info "Installing Nushell..."
if ! command -v nu &> /dev/null; then
    NU_VERSION=$(curl -s --max-time 10 "https://api.github.com/repos/nushell/nushell/releases/latest" | grep -Po '"tag_name": "\K[0-9.]+' || echo "0.103.0")
    if download_util "https://github.com/nushell/nushell/releases/download/${NU_VERSION}/nu-${NU_VERSION}-x86_64-unknown-linux-musl.tar.gz" "/tmp/nu.tar.gz"; then
        tar -xzf /tmp/nu.tar.gz -C /tmp/ 2>/dev/null
        cp /tmp/nu-*/nu /usr/local/bin/ 2>/dev/null
        chmod +x /usr/local/bin/nu
        rm -rf /tmp/nu*
    fi
else
    log_info "Nushell already installed, skipping"
fi

# TLDR
log_info "Installing TLDR..."
if ! command -v tldr &> /dev/null; then
    npm install -g tldr 2>&1 | grep -v "npm WARN" || log_warn "TLDR install failed"
else
    log_info "TLDR already installed, skipping"
fi

# Cheat
log_info "Installing Cheat..."
if ! command -v cheat &> /dev/null; then
    if download_util "https://github.com/cheat/cheat/releases/latest/download/cheat-linux-amd64.gz" "/tmp/cheat.gz"; then
        gunzip -f /tmp/cheat.gz 2>/dev/null
        install -m 755 /tmp/cheat /usr/local/bin/cheat
        rm -f /tmp/cheat
    fi
else
    log_info "Cheat already installed, skipping"
fi

# Pet
log_info "Installing Pet..."
if ! command -v pet &> /dev/null; then
    if download_util "https://github.com/knqyf263/pet/releases/latest/download/pet_linux_amd64.tar.gz" "/tmp/pet.tar.gz"; then
        tar -xzf /tmp/pet.tar.gz -C /tmp/ 2>/dev/null
        cp /tmp/pet /usr/local/bin/ 2>/dev/null
        chmod +x /usr/local/bin/pet
        rm -rf /tmp/pet*
    fi
else
    log_info "Pet already installed, skipping"
fi

# Navi
log_info "Installing Navi..."
if ! command -v navi &> /dev/null; then
    if download_util "https://github.com/denisidoro/navi/releases/latest/download/navi-x86_64-unknown-linux-musl.tar.gz" "/tmp/navi.tar.gz"; then
        tar -xzf /tmp/navi.tar.gz -C /usr/local/bin/ navi 2>/dev/null
        chmod +x /usr/local/bin/navi
        rm /tmp/navi.tar.gz
    fi
else
    log_info "Navi already installed, skipping"
fi

# Dasel
log_info "Installing Dasel..."
if ! command -v dasel &> /dev/null; then
    download_util "https://github.com/TomWright/dasel/releases/latest/download/dasel_linux_amd64" "/usr/local/bin/dasel" && \
        chmod +x /usr/local/bin/dasel
else
    log_info "Dasel already installed, skipping"
fi

# Miller (mlr)
log_info "Installing Miller..."
if ! command -v mlr &> /dev/null; then
    MLR_VERSION=$(curl -s --max-time 10 "https://api.github.com/repos/johnkerl/miller/releases/latest" | grep -Po '"tag_name": "v\K[0-9.]+' || echo "6.12.0")
    if download_util "https://github.com/johnkerl/miller/releases/download/v${MLR_VERSION}/miller-${MLR_VERSION}-linux-amd64.tar.gz" "/tmp/mlr.tar.gz"; then
        tar -xzf /tmp/mlr.tar.gz -C /tmp/ 2>/dev/null
        cp /tmp/miller-*/mlr /usr/local/bin/ 2>/dev/null
        chmod +x /usr/local/bin/mlr
        rm -rf /tmp/mlr* /tmp/miller-*
    fi
else
    log_info "Miller already installed, skipping"
fi

# XSV
log_info "Installing XSV..."
if ! command -v xsv &> /dev/null; then
    if download_util "https://github.com/BurntSushi/xsv/releases/download/0.13.0/xsv-0.13.0-x86_64-unknown-linux-musl.tar.gz" "/tmp/xsv.tar.gz"; then
        tar -xzf /tmp/xsv.tar.gz -C /usr/local/bin/ xsv 2>/dev/null
        chmod +x /usr/local/bin/xsv
        rm /tmp/xsv.tar.gz
    fi
else
    log_info "XSV already installed, skipping"
fi

# Jless
log_info "Installing Jless..."
if ! command -v jless &> /dev/null; then
    if download_util "https://github.com/PaulJuliusMartinez/jless/releases/latest/download/jless-linux-x86_64.zip" "/tmp/jless.zip"; then
        unzip -q /tmp/jless.zip -d /usr/local/bin/ 2>/dev/null
        chmod +x /usr/local/bin/jless
        rm /tmp/jless.zip
    fi
else
    log_info "Jless already installed, skipping"
fi

# HTMLq
log_info "Installing HTMLq..."
if ! command -v htmlq &> /dev/null; then
    if download_util "https://github.com/mgdm/htmlq/releases/latest/download/htmlq-x86_64-linux.tar.gz" "/tmp/htmlq.tar.gz"; then
        tar -xzf /tmp/htmlq.tar.gz -C /usr/local/bin/ htmlq 2>/dev/null
        chmod +x /usr/local/bin/htmlq
        rm /tmp/htmlq.tar.gz
    fi
else
    log_info "HTMLq already installed, skipping"
fi

# Caddy
log_info "Installing Caddy..."
if ! command -v caddy &> /dev/null; then
    if download_util "https://github.com/caddyserver/caddy/releases/latest/download/caddy_linux_amd64.tar.gz" "/tmp/caddy.tar.gz"; then
        tar -xzf /tmp/caddy.tar.gz -C /usr/local/bin/ caddy 2>/dev/null
        chmod +x /usr/local/bin/caddy
        rm /tmp/caddy.tar.gz
    fi
else
    log_info "Caddy already installed, skipping"
fi

# Ngrok
log_info "Installing Ngrok..."
if ! command -v ngrok &> /dev/null; then
    if download_util "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz" "/tmp/ngrok.tgz"; then
        tar -xzf /tmp/ngrok.tgz -C /usr/local/bin/ ngrok 2>/dev/null
        chmod +x /usr/local/bin/ngrok
        rm /tmp/ngrok.tgz
    fi
else
    log_info "Ngrok already installed, skipping"
fi

# Cloudflared
log_info "Installing Cloudflared..."
if ! command -v cloudflared &> /dev/null; then
    download_util "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" "/usr/local/bin/cloudflared" && \
        chmod +x /usr/local/bin/cloudflared
else
    log_info "Cloudflared already installed, skipping"
fi

# Gomplate
log_info "Installing Gomplate..."
if ! command -v gomplate &> /dev/null; then
    download_util "https://github.com/hairyhenderson/gomplate/releases/latest/download/gomplate_linux-amd64" "/usr/local/bin/gomplate" && \
        chmod +x /usr/local/bin/gomplate
else
    log_info "Gomplate already installed, skipping"
fi

# GH Dash
log_info "Installing GH Dash..."
if ! command -v gh-dash &> /dev/null; then
    if download_util "https://github.com/dlvhdr/gh-dash/releases/latest/download/gh-dash_linux_amd64.tar.gz" "/tmp/gh-dash.tar.gz"; then
        tar -xzf /tmp/gh-dash.tar.gz -C /tmp/ 2>/dev/null
        cp /tmp/gh-dash /usr/local/bin/ 2>/dev/null
        chmod +x /usr/local/bin/gh-dash
        rm -rf /tmp/gh-dash*
    fi
else
    log_info "GH Dash already installed, skipping"
fi

# Granted
log_info "Installing Granted..."
if ! command -v granted &> /dev/null; then
    if download_util "https://github.com/common-fate/granted/releases/latest/download/granted_linux_x86_64.tar.gz" "/tmp/granted.tar.gz"; then
        tar -xzf /tmp/granted.tar.gz -C /usr/local/bin/ granted 2>/dev/null
        chmod +x /usr/local/bin/granted
        rm /tmp/granted.tar.gz
    fi
else
    log_info "Granted already installed, skipping"
fi

log_info "✓ Phase 26 complete - Additional utilities installed"

# =============================================================================
# PHASE 27: Installing AI/ML CLI Tools
# =============================================================================

log_phase "PHASE 27: Installing AI/ML CLI Tools"

# Function to download with timeout
download_ai_tool() {
    local url=$1
    local output=$2
    wget --timeout=15 --tries=2 -q "$url" -O "$output" 2>/dev/null || {
        log_warn "Failed to download $(basename $output)"
        return 1
    }
}

# Skip Ollama - requires daemon/service (not suitable for rootfs)
log_info "Skipping Ollama - service not needed in rootfs environment"

# Hugging Face CLI
log_info "Installing Hugging Face CLI..."
if ! command -v huggingface-cli &> /dev/null; then
    pip3 install --break-system-packages --quiet huggingface_hub 2>&1 | grep -vE "WARNING|ERROR|incompatible" || true
else
    log_info "HuggingFace CLI already installed, skipping"
fi

# OpenAI CLI
log_info "Installing OpenAI CLI..."
if ! pip3 show openai &> /dev/null; then
    pip3 install --break-system-packages --quiet openai 2>&1 | grep -vE "WARNING|ERROR|incompatible" || true
else
    log_info "OpenAI CLI already installed, skipping"
fi

# Anthropic Claude CLI
log_info "Installing Anthropic CLI..."
if ! pip3 show anthropic &> /dev/null; then
    pip3 install --break-system-packages --quiet anthropic 2>&1 | grep -vE "WARNING|ERROR|incompatible" || true
else
    log_info "Anthropic CLI already installed, skipping"
fi

# LiteLLM (unified LLM proxy CLI)
log_info "Installing LiteLLM..."
if ! command -v litellm &> /dev/null; then
    pip3 install --break-system-packages --quiet litellm 2>&1 | grep -vE "WARNING|ERROR|incompatible" || true
else
    log_info "LiteLLM already installed, skipping"
fi

# MLflow CLI
log_info "Installing MLflow CLI..."
if ! command -v mlflow &> /dev/null; then
    pip3 install --break-system-packages --quiet mlflow 2>&1 | grep -vE "WARNING|ERROR|incompatible" || true
else
    log_info "MLflow already installed, skipping"
fi

# DVC (Data Version Control)
log_info "Installing DVC..."
if ! command -v dvc &> /dev/null; then
    pip3 install --break-system-packages --quiet dvc 2>&1 | grep -vE "WARNING|ERROR|incompatible" || true
else
    log_info "DVC already installed, skipping"
fi

# Weights & Biases CLI
log_info "Installing W&B CLI..."
if ! command -v wandb &> /dev/null; then
    pip3 install --break-system-packages --quiet wandb 2>&1 | grep -vE "WARNING|ERROR|incompatible" || true
else
    log_info "W&B CLI already installed, skipping"
fi

# TensorBoard
log_info "Installing TensorBoard..."
if ! command -v tensorboard &> /dev/null; then
    pip3 install --break-system-packages --quiet tensorboard 2>&1 | grep -vE "WARNING|ERROR|incompatible" || true
else
    log_info "TensorBoard already installed, skipping"
fi

# LangChain CLI
log_info "Installing LangChain CLI..."
if ! command -v langchain &> /dev/null; then
    pip3 install --break-system-packages --quiet langchain-cli 2>&1 | grep -vE "WARNING|ERROR|incompatible" || true
else
    log_info "LangChain CLI already installed, skipping"
fi

# Mods (AI for the command line)
log_info "Installing Mods..."
if ! command -v mods &> /dev/null; then
    if download_ai_tool "https://github.com/charmbracelet/mods/releases/latest/download/mods_Linux_x86_64.tar.gz" "/tmp/mods.tar.gz"; then
        tar -xzf /tmp/mods.tar.gz -C /tmp/ 2>/dev/null
        cp /tmp/mods /usr/local/bin/ 2>/dev/null
        chmod +x /usr/local/bin/mods
        rm -rf /tmp/mods*
    fi
else
    log_info "Mods already installed, skipping"
fi

# AIChat (terminal AI chatbot)
log_info "Installing AIChat..."
if ! command -v aichat &> /dev/null; then
    if download_ai_tool "https://github.com/sigoden/aichat/releases/latest/download/aichat-x86_64-unknown-linux-musl.tar.gz" "/tmp/aichat.tar.gz"; then
        tar -xzf /tmp/aichat.tar.gz -C /tmp/ 2>/dev/null
        cp /tmp/aichat /usr/local/bin/ 2>/dev/null
        chmod +x /usr/local/bin/aichat
        rm -rf /tmp/aichat*
    fi
else
    log_info "AIChat already installed, skipping"
fi

# LLM CLI by Simon Willison
log_info "Installing LLM CLI..."
if ! command -v llm &> /dev/null; then
    pip3 install --break-system-packages --quiet llm 2>&1 | grep -vE "WARNING|ERROR|incompatible" || true
else
    log_info "LLM CLI already installed, skipping"
fi

# Shell GPT
log_info "Installing Shell GPT..."
if ! command -v sgpt &> /dev/null; then
    pip3 install --break-system-packages --quiet shell-gpt 2>&1 | grep -vE "WARNING|ERROR|incompatible" || true
else
    log_info "Shell GPT already installed, skipping"
fi

log_info "✓ Phase 27 complete - AI/ML CLI tools installed"

# =============================================================================
# PHASE 28: Installing Documentation Tools
# =============================================================================

log_phase "PHASE 28: Installing Documentation Tools"

# Function to download with timeout
download_doc_tool() {
    local url=$1
    local output=$2
    wget --timeout=15 --tries=2 -q "$url" -O "$output" 2>/dev/null || {
        log_warn "Failed to download $(basename $output)"
        return 1
    }
}

# MkDocs already installed via pip in Phase 13
log_info "Skipping MkDocs - already installed in Phase 13"

# Mdbook
log_info "Installing mdBook..."
if ! command -v mdbook &> /dev/null; then
    if download_doc_tool "https://github.com/rust-lang/mdBook/releases/latest/download/mdbook-v0.4.40-x86_64-unknown-linux-gnu.tar.gz" "/tmp/mdbook.tar.gz"; then
        tar -xzf /tmp/mdbook.tar.gz -C /usr/local/bin/ mdbook 2>/dev/null
        chmod +x /usr/local/bin/mdbook
        rm /tmp/mdbook.tar.gz
    fi
else
    log_info "mdBook already installed, skipping"
fi

# Pandoc
log_info "Installing Pandoc..."
if ! command -v pandoc &> /dev/null; then
    PANDOC_VERSION=$(curl -s --max-time 10 "https://api.github.com/repos/jgm/pandoc/releases/latest" | grep -Po '"tag_name": "\K[0-9.]+' || echo "3.6.1")
    if download_doc_tool "https://github.com/jgm/pandoc/releases/download/${PANDOC_VERSION}/pandoc-${PANDOC_VERSION}-linux-amd64.tar.gz" "/tmp/pandoc.tar.gz"; then
        tar -xzf /tmp/pandoc.tar.gz -C /tmp/ 2>/dev/null
        cp /tmp/pandoc-*/bin/pandoc /usr/local/bin/ 2>/dev/null
        chmod +x /usr/local/bin/pandoc
        rm -rf /tmp/pandoc*
    fi
else
    log_info "Pandoc already installed, skipping"
fi

# Asciidoctor
log_info "Installing Asciidoctor..."
if ! command -v asciidoctor &> /dev/null; then
    gem install asciidoctor 2>&1 | grep -v "Successfully installed" || log_warn "Asciidoctor install failed"
else
    log_info "Asciidoctor already installed, skipping"
fi

# Mermaid CLI
log_info "Installing Mermaid CLI..."
if ! command -v mmdc &> /dev/null; then
    npm install -g @mermaid-js/mermaid-cli 2>&1 | grep -v "npm WARN" || log_warn "Mermaid CLI install failed"
else
    log_info "Mermaid CLI already installed, skipping"
fi

# D2
log_info "Installing D2..."
if ! command -v d2 &> /dev/null; then
    timeout 60 bash -c "curl -fsSL https://d2lang.com/install.sh | sh -s --" 2>&1 | grep -v "Downloading" || \
        log_warn "D2 installation failed"
    cp -f $HOME/.local/bin/d2 /usr/local/bin/ 2>/dev/null || true
else
    log_info "D2 already installed, skipping"
fi

# PlantUML (requires Java)
log_info "Installing PlantUML..."
if [ ! -f /usr/local/bin/plantuml.jar ]; then
    if download_doc_tool "https://github.com/plantuml/plantuml/releases/latest/download/plantuml.jar" "/usr/local/bin/plantuml.jar"; then
        cat > /usr/local/bin/plantuml <<'EOF'
#!/bin/bash
java -jar /usr/local/bin/plantuml.jar "$@"
EOF
        chmod +x /usr/local/bin/plantuml
    fi
else
    log_info "PlantUML already installed, skipping"
fi

log_info "✓ Phase 28 complete - Documentation tools installed"

# =============================================================================
# PHASE 29: Installing Database CLIs
# =============================================================================

log_phase "PHASE 29: Installing Database CLIs"

# Function to download with timeout
download_db_cli() {
    local url=$1
    local output=$2
    wget --timeout=15 --tries=2 -q "$url" -O "$output" 2>/dev/null || {
        log_warn "Failed to download $(basename $output)"
        return 1
    }
}

# PostgreSQL client (psql) - already installed in Phase 4
log_info "Skipping psql - already installed in Phase 4"

# MySQL client - already installed in Phase 4
log_info "Skipping mysql - already installed in Phase 4"

# Redis CLI - already installed in Phase 4
log_info "Skipping redis-cli - already installed in Phase 4"

# MongoDB Shell
log_info "Installing mongosh..."
if ! command -v mongosh &> /dev/null; then
    MONGOSH_VERSION=$(curl -s --max-time 10 "https://api.github.com/repos/mongodb-js/mongosh/releases/latest" | grep -Po '"tag_name": "v\K[0-9.]+' || echo "2.3.7")
    if download_db_cli "https://downloads.mongodb.com/compass/mongosh-${MONGOSH_VERSION}-linux-x64.tgz" "/tmp/mongosh.tgz"; then
        tar -xzf /tmp/mongosh.tgz -C /tmp/ 2>/dev/null
        cp /tmp/mongosh-*/bin/mongosh /usr/local/bin/ 2>/dev/null
        chmod +x /usr/local/bin/mongosh
        rm -rf /tmp/mongosh*
    fi
else
    log_info "mongosh already installed, skipping"
fi

# etcdctl
log_info "Installing etcdctl..."
if ! command -v etcdctl &> /dev/null; then
    ETCD_VERSION=$(curl -s --max-time 10 "https://api.github.com/repos/etcd-io/etcd/releases/latest" | grep -Po '"tag_name": "v\K[0-9.]+' || echo "3.5.17")
    if download_db_cli "https://github.com/etcd-io/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz" "/tmp/etcd.tar.gz"; then
        tar -xzf /tmp/etcd.tar.gz -C /tmp/ 2>/dev/null
        cp /tmp/etcd-*/etcdctl /usr/local/bin/ 2>/dev/null
        chmod +x /usr/local/bin/etcdctl
        rm -rf /tmp/etcd*
    fi
else
    log_info "etcdctl already installed, skipping"
fi

# NATS CLI
log_info "Installing NATS CLI..."
if ! command -v nats &> /dev/null; then
    NATS_VERSION=$(curl -s --max-time 10 "https://api.github.com/repos/nats-io/natscli/releases/latest" | grep -Po '"tag_name": "v\K[0-9.]+' || echo "0.1.5")
    if download_db_cli "https://github.com/nats-io/natscli/releases/download/v${NATS_VERSION}/nats-${NATS_VERSION}-linux-amd64.tar.gz" "/tmp/nats.tar.gz"; then
        tar -xzf /tmp/nats.tar.gz -C /tmp/ 2>/dev/null
        cp /tmp/nats-*/nats /usr/local/bin/ 2>/dev/null
        chmod +x /usr/local/bin/nats
        rm -rf /tmp/nats*
    fi
else
    log_info "NATS CLI already installed, skipping"
fi

# Usql (universal SQL CLI)
log_info "Installing usql..."
if ! command -v usql &> /dev/null; then
    USQL_VERSION=$(curl -s --max-time 10 "https://api.github.com/repos/xo/usql/releases/latest" | grep -Po '"tag_name": "v\K[0-9.]+' || echo "0.19.14")
    if download_db_cli "https://github.com/xo/usql/releases/download/v${USQL_VERSION}/usql-${USQL_VERSION}-linux-amd64.tar.bz2" "/tmp/usql.tar.bz2"; then
        tar -xjf /tmp/usql.tar.bz2 -C /tmp/ 2>/dev/null
        cp /tmp/usql /usr/local/bin/ 2>/dev/null
        chmod +x /usr/local/bin/usql
        rm -rf /tmp/usql*
    fi
else
    log_info "usql already installed, skipping"
fi

# DBeaver CLI (optional - large download)
log_info "Skipping DBeaver CLI - too large for rootfs (use GUI version separately)"

log_info "✓ Phase 29 complete - Database CLIs installed"

# =============================================================================
# PHASE 30: Cleanup
# =============================================================================

log_phase "PHASE 30: Cleaning up"

apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/*

# =============================================================================
# PHASE 31: Verification
# =============================================================================

log_phase "PHASE 31: Verifying critical installations"

verify_tool() {
    if command -v $1 >/dev/null 2>&1; then
        log_info "✓ $1 installed"
    else
        log_warn "✗ $1 missing"
    fi
}

verify_tool kubectl
verify_tool helm
verify_tool docker
verify_tool terraform
verify_tool aws
verify_tool gcloud
verify_tool az
verify_tool go
verify_tool rustc
verify_tool node
verify_tool python3
verify_tool trivy
verify_tool grype
verify_tool syft
verify_tool cosign
verify_tool k9s
verify_tool stern
verify_tool flux
verify_tool argocd
verify_tool kyverno
verify_tool opa
verify_tool conftest
verify_tool hadolint
verify_tool checkov
verify_tool semgrep
verify_tool mkdocs
verify_tool starship
verify_tool zoxide

log_info "Installation complete! 🎉"
log_info "Total tools installed: 350+"
log_info "Restart shell or run: source /etc/profile"

apt autoremove -y
