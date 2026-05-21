#!/bin/bash
# =============================================================================
# Dev Machine Rootfs — Tool Installation Script
# Ubuntu 24.04 LTS | Official sources only | Pinned versions (March 2026)
# =============================================================================
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export TZ=UTC

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_phase() { echo -e "\n${BLUE}=== $1 ===${NC}\n"; }

# =============================================================================
# PINNED VERSIONS — bump these to upgrade
# =============================================================================
K9S_VERSION="v0.50.10"
KUBECTX_VERSION="v0.9.5"
STERN_VERSION="v1.33.0"
KUSTOMIZE_VERSION="v5.7.1"
JQ_VERSION="1.8.1"
YQ_VERSION="v4.46.1"
FZF_VERSION="0.65.2"
RG_VERSION="14.1.1"
DIVE_VERSION="v0.13.1"
HADOLINT_VERSION="v2.12.0"
TRIVY_VERSION="0.64.1"
GITLEAKS_VERSION="v8.28.0"
COSIGN_VERSION="v3.0.3"
SYFT_VERSION="v1.26.1"
EKSCTL_VERSION="v0.226.0"

# =============================================================================
# PHASE 1: Base system packages
# =============================================================================
log_phase "PHASE 1: Base system packages"

apt-get update
apt-get install -y --no-install-recommends \
  apt-transport-https \
  software-properties-common \
  zip \
  xz-utils \
  tmux \
  nano \
  lsof \
  file \
  git-lfs \
  openssl \
  nmap \
  socat \
  ssh \
  fontconfig \
  maven

apt-get clean
rm -rf /var/lib/apt/lists/*
log_info "Base packages installed."

# =============================================================================
# PHASE 2: Java 21 — official Ubuntu repo
# https://openjdk.org/install/
# =============================================================================
log_phase "PHASE 2: Java 21"

apt-get update
apt-get install -y --no-install-recommends openjdk-21-jdk
java -version
apt-get clean && rm -rf /var/lib/apt/lists/*

# =============================================================================
# PHASE 3: Python 3 — official Ubuntu repo
# https://www.python.org
# =============================================================================
log_phase "PHASE 3: Python 3"

apt-get update
apt-get install -y --no-install-recommends \
  python3 \
  python3-pip \
  python3-venv \
  python3-dev \
  python3-setuptools
python3 --version && pip3 --version
apt-get clean && rm -rf /var/lib/apt/lists/*

# =============================================================================
# PHASE 4: Node.js LTS — official NodeSource repo
# https://github.com/nodesource/distributions
# =============================================================================
log_phase "PHASE 4: Node.js LTS"

curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs
node --version && npm --version
apt-get clean && rm -rf /var/lib/apt/lists/*

# =============================================================================
# PHASE 5: Docker CE — official Docker repo
# https://docs.docker.com/engine/install/ubuntu/
# =============================================================================
log_phase "PHASE 5: Docker CE ... Installed via install-docker.sh already"

# =============================================================================
# PHASE 6: kubectl — official Kubernetes apt repo
# https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
# =============================================================================
log_phase "PHASE 6: kubectl"

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubectl
kubectl version --client
apt-get clean && rm -rf /var/lib/apt/lists/*

# =============================================================================
# PHASE 7: Helm — official install script
# https://helm.sh/docs/intro/install/
# =============================================================================
log_phase "PHASE 7: Helm"

curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
  | bash
helm version

# =============================================================================
# PHASE 8: Terraform — official HashiCorp apt repo
# https://developer.hashicorp.com/terraform/install
# =============================================================================
log_phase "PHASE 8: Terraform"

curl -fsSL https://apt.releases.hashicorp.com/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/hashicorp-archive-keyring.gpg
chmod 644 /etc/apt/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  > /etc/apt/sources.list.d/hashicorp.list

apt-get update
apt-get install -y terraform
terraform version
apt-get clean && rm -rf /var/lib/apt/lists/*

# =============================================================================
# PHASE 9: GitHub CLI — official GitHub apt repo
# https://github.com/cli/cli/blob/trunk/docs/install_linux.md
# =============================================================================
log_phase "PHASE 9: GitHub CLI"

curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  | dd of=/etc/apt/keyrings/githubcli-archive-keyring.gpg
chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] \
  https://cli.github.com/packages stable main" \
  > /etc/apt/sources.list.d/github-cli.list

apt-get update
apt-get install -y gh
gh --version
apt-get clean && rm -rf /var/lib/apt/lists/*

# =============================================================================
# PHASE 10: AWS CLI v2 — official installer
# https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
# =============================================================================
log_phase "PHASE 10: AWS CLI v2"

ARCH="$(uname -m)"
[[ "$ARCH" == "x86_64" ]] && AWS_ARCH="x86_64" || AWS_ARCH="aarch64"

curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip" \
  -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp/
/tmp/aws/install
rm -rf /tmp/aws /tmp/awscliv2.zip
aws --version

# =============================================================================
# PHASE 11: Skopeo — official Ubuntu repo
# https://github.com/containers/skopeo/blob/main/install.md
# =============================================================================
log_phase "PHASE 11: Skopeo"

apt-get update
apt-get install -y skopeo
skopeo --version
apt-get clean && rm -rf /var/lib/apt/lists/*

# =============================================================================
# PHASE 12: k9s — official GitHub release
# https://github.com/derailed/k9s/releases
# =============================================================================
log_phase "PHASE 12: k9s ${K9S_VERSION}"

curl -fsSL "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz" \
  -o /tmp/k9s.tar.gz
tar -xzf /tmp/k9s.tar.gz -C /usr/local/bin k9s
chmod +x /usr/local/bin/k9s
rm /tmp/k9s.tar.gz
k9s version

# =============================================================================
# PHASE 13: kubectx + kubens — official GitHub release
# https://github.com/ahmetb/kubectx/releases
# =============================================================================
log_phase "PHASE 13: kubectx + kubens ${KUBECTX_VERSION}"

curl -fsSL "https://github.com/ahmetb/kubectx/releases/download/${KUBECTX_VERSION}/kubectx_${KUBECTX_VERSION}_linux_x86_64.tar.gz" \
  -o /tmp/kubectx.tar.gz
tar -xzf /tmp/kubectx.tar.gz -C /usr/local/bin kubectx
chmod +x /usr/local/bin/kubectx && rm /tmp/kubectx.tar.gz

curl -fsSL "https://github.com/ahmetb/kubectx/releases/download/${KUBECTX_VERSION}/kubens_${KUBECTX_VERSION}_linux_x86_64.tar.gz" \
  -o /tmp/kubens.tar.gz
tar -xzf /tmp/kubens.tar.gz -C /usr/local/bin kubens
chmod +x /usr/local/bin/kubens && rm /tmp/kubens.tar.gz

kubectx --version && kubens --version

# =============================================================================
# PHASE 14: kustomize — official GitHub release
# https://github.com/kubernetes-sigs/kustomize/releases
# =============================================================================
log_phase "PHASE 14: kustomize ${KUSTOMIZE_VERSION}"

curl -fsSL "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz" \
  -o /tmp/kustomize.tar.gz
tar -xzf /tmp/kustomize.tar.gz -C /usr/local/bin kustomize
chmod +x /usr/local/bin/kustomize && rm /tmp/kustomize.tar.gz
kustomize version

# =============================================================================
# PHASE 15: stern — official GitHub release
# https://github.com/stern/stern/releases
# =============================================================================
log_phase "PHASE 15: stern ${STERN_VERSION}"

curl -fsSL "https://github.com/stern/stern/releases/download/${STERN_VERSION}/stern_${STERN_VERSION#v}_linux_amd64.tar.gz" \
  -o /tmp/stern.tar.gz
tar -xzf /tmp/stern.tar.gz -C /usr/local/bin stern
chmod +x /usr/local/bin/stern && rm /tmp/stern.tar.gz
stern --version

# =============================================================================
# PHASE 16: jq — official GitHub release
# https://github.com/jqlang/jq/releases
# =============================================================================
log_phase "PHASE 16: jq ${JQ_VERSION}"

curl -fsSL "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-amd64" \
  -o /usr/local/bin/jq
chmod +x /usr/local/bin/jq
jq --version

# =============================================================================
# PHASE 17: yq — official GitHub release (mikefarah/yq)
# https://github.com/mikefarah/yq/releases
# =============================================================================
log_phase "PHASE 17: yq ${YQ_VERSION}"

curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" \
  -o /usr/local/bin/yq
chmod +x /usr/local/bin/yq
yq --version

# =============================================================================
# PHASE 18: fzf — official GitHub release
# https://github.com/junegunn/fzf/releases
# =============================================================================
log_phase "PHASE 18: fzf ${FZF_VERSION}"

curl -fsSL "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-linux_amd64.tar.gz" \
  -o /tmp/fzf.tar.gz
tar -xzf /tmp/fzf.tar.gz -C /usr/local/bin fzf
chmod +x /usr/local/bin/fzf && rm /tmp/fzf.tar.gz
fzf --version

# =============================================================================
# PHASE 19: ripgrep — official GitHub release
# https://github.com/BurntSushi/ripgrep/releases
# =============================================================================
log_phase "PHASE 19: ripgrep ${RG_VERSION}"

curl -fsSL "https://github.com/BurntSushi/ripgrep/releases/download/${RG_VERSION}/ripgrep-${RG_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
  -o /tmp/rg.tar.gz
tar -xzf /tmp/rg.tar.gz -C /tmp
mv "/tmp/ripgrep-${RG_VERSION}-x86_64-unknown-linux-musl/rg" /usr/local/bin/rg
chmod +x /usr/local/bin/rg
rm -rf /tmp/rg.tar.gz "/tmp/ripgrep-${RG_VERSION}-x86_64-unknown-linux-musl"
rg --version

# =============================================================================
# PHASE 20: dive — official GitHub release
# https://github.com/wagoodman/dive/releases
# =============================================================================
log_phase "PHASE 20: dive ${DIVE_VERSION}"

curl -fsSL "https://github.com/wagoodman/dive/releases/download/${DIVE_VERSION}/dive_${DIVE_VERSION#v}_linux_amd64.tar.gz" \
  -o /tmp/dive.tar.gz
tar -xzf /tmp/dive.tar.gz -C /usr/local/bin dive
chmod +x /usr/local/bin/dive && rm /tmp/dive.tar.gz
dive --version

# =============================================================================
# PHASE 21: hadolint — official GitHub release
# https://github.com/hadolint/hadolint/releases
# =============================================================================
log_phase "PHASE 21: hadolint ${HADOLINT_VERSION}"

curl -fsSL "https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}/hadolint-Linux-x86_64" \
  -o /usr/local/bin/hadolint
chmod +x /usr/local/bin/hadolint
hadolint --version

# =============================================================================
# PHASE 22: trivy — official Aqua apt repo
# https://aquasecurity.github.io/trivy/latest/getting-started/installation/
# =============================================================================
log_phase "PHASE 22: trivy v${TRIVY_VERSION}"

curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key \
  | gpg --dearmor -o /etc/apt/keyrings/trivy.gpg
chmod 644 /etc/apt/keyrings/trivy.gpg

echo "deb [signed-by=/etc/apt/keyrings/trivy.gpg] \
  https://aquasecurity.github.io/trivy-repo/deb \
  $(lsb_release -sc) main" \
  > /etc/apt/sources.list.d/trivy.list

apt-get update
apt-get install -y trivy
trivy --version
apt-get clean && rm -rf /var/lib/apt/lists/*

# =============================================================================
# PHASE 23: gitleaks — official GitHub release
# https://github.com/gitleaks/gitleaks/releases
# =============================================================================
log_phase "PHASE 23: gitleaks ${GITLEAKS_VERSION}"

curl -fsSL "https://github.com/gitleaks/gitleaks/releases/download/${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION#v}_linux_x64.tar.gz" \
  -o /tmp/gitleaks.tar.gz
tar -xzf /tmp/gitleaks.tar.gz -C /usr/local/bin gitleaks
chmod +x /usr/local/bin/gitleaks && rm /tmp/gitleaks.tar.gz
gitleaks version

# =============================================================================
# PHASE 24: cosign — official GitHub release (sigstore/cosign)
# https://docs.sigstore.dev/cosign/system_config/installation/
# =============================================================================
log_phase "PHASE 24: cosign ${COSIGN_VERSION}"

curl -fsSL "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-amd64" \
  -o /usr/local/bin/cosign
chmod +x /usr/local/bin/cosign
cosign version

# =============================================================================
# PHASE 25: syft — official install script (anchore/syft)
# https://github.com/anchore/syft
# =============================================================================
log_phase "PHASE 25: syft ${SYFT_VERSION}"

curl -fsSL https://raw.githubusercontent.com/anchore/syft/main/install.sh \
  | sh -s -- -b /usr/local/bin "${SYFT_VERSION}"
syft --version

# =============================================================================
# PHASE 26: eksctl — official GitHub release (eksctl-io/eksctl)
# https://docs.aws.amazon.com/eks/latest/eksctl/installation.html
# =============================================================================
log_phase "PHASE 26: eksctl ${EKSCTL_VERSION}"

# For ARM systems, set ARCH to: arm64, armv6 or armv7
ARCH=amd64
PLATFORM=$(uname -s)_${ARCH}

curl -sLO "https://github.com/eksctl-io/eksctl/releases/download/${EKSCTL_VERSION}/eksctl_${PLATFORM}.tar.gz"

# Verify checksum
curl -sL "https://github.com/eksctl-io/eksctl/releases/download/${EKSCTL_VERSION}/eksctl_checksums.txt" \
  | grep "${PLATFORM}" | sha256sum --check

tar -xzf "eksctl_${PLATFORM}.tar.gz" -C /tmp && rm "eksctl_${PLATFORM}.tar.gz"
install -m 0755 /tmp/eksctl /usr/local/bin && rm /tmp/eksctl
eksctl version

# =============================================================================
# PHASE 27: Python tools via pip
# =============================================================================
log_phase "PHASE 27: Python tools via pip"

pip3 install --break-system-packages \
  pre-commit \
  ansible \
  ansible-lint \
  yamllint

pre-commit --version
ansible --version
yamllint --version

# =============================================================================
# PHASE 28: Database CLI Clients — official Ubuntu repos
# https://dev.mysql.com/doc/refman/en/mysql.html
# https://www.postgresql.org/docs/current/app-psql.html
# https://sqlite.org/cli.html
# https://redis.io/docs/ui/cli/
# =============================================================================
log_phase "PHASE 28: Database CLI Clients"

apt-get update
apt-get install -y --no-install-recommends \
  mysql-client \
  postgresql-client \
  sqlite3 \
  redis-tools

mysql --version
psql --version
sqlite3 --version
redis-cli --version
apt-get clean && rm -rf /var/lib/apt/lists/*

# =============================================================================
# PHASE 29: mongosh — official MongoDB apt repo
# https://www.mongodb.com/docs/mongodb-shell/install/
# =============================================================================
log_phase "PHASE 29: mongosh"

curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc \
  | gpg --dearmor -o /etc/apt/keyrings/mongodb-server-8.0.gpg
chmod 644 /etc/apt/keyrings/mongodb-server-8.0.gpg

echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/mongodb-server-8.0.gpg] \
  https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/8.0 multiverse" \
  > /etc/apt/sources.list.d/mongodb-org-8.0.list

apt-get update
apt-get install -y --no-install-recommends mongodb-mongosh
mongosh --version
apt-get clean && rm -rf /var/lib/apt/lists/*

# =============================================================================
# PHASE 30: Final cleanup
# =============================================================================
log_phase "PHASE 30: Final cleanup"

apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

log_info "============================================"
log_info "All tools installed successfully."
log_info "============================================"
