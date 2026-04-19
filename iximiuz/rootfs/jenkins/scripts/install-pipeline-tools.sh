#!/bin/bash
set -euo pipefail

########################################################################
# Pipeline Tools Installation Script
#
# Installs all CI/CD tools required by Jenkins pipelines on Ubuntu 24.04.
# All tools installed via official upstream sources only.
#
# Versions pinned as of April 2026:
#   Maven      3.9.15    (Apache — latest stable)
#   Node.js    22 LTS    (NodeSource — Jod, LTS until Apr 2027)
#   Python     3.12.3    (Ubuntu 24.04 built-in)
#   Docker     latest    (Docker official apt repo)
#   Trivy      0.69.3    (PINNED — 0.69.4 was supply chain attack CVE-2026-33634)
#   AWS CLI    v2        (AWS official installer — always latest)
#   kubectl    1.35      (Kubernetes stable — 1.35.4)
#   Helm       4.1.4     (Helm official script with explicit DESIRED_VERSION)
#   Terraform  1.14.x    (HashiCorp apt repo — 1.15 is RC only)
#   Ansible    core 2.20 (PPA — latest stable, EOL May 2027)
#
# Author: Muhammad Ibtisam Iqbal
########################################################################

echo "================================================================"
echo " Installing Jenkins CI/CD Pipeline Tools"
echo " Ubuntu 24.04 | April 2026"
echo "================================================================"

# ── Base dependencies ─────────────────────────────────────────────────
apt-get update -qq
apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg wget unzip lsb-release \
    software-properties-common apt-transport-https

install -m 0755 -d /etc/apt/keyrings

# ── 1. Maven 3.9.15 (Apache official binary) ─────────────────────────
MAVEN_VERSION="3.9.15"
echo ""
echo "[1/10] Installing Maven ${MAVEN_VERSION}..."
wget -q "https://downloads.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
    -O /tmp/maven.tar.gz
tar -xzf /tmp/maven.tar.gz -C /opt/
ln -s /opt/apache-maven-${MAVEN_VERSION} /opt/maven
ln -s /opt/maven/bin/mvn /usr/local/bin/mvn
rm /tmp/maven.tar.gz
echo "      ✓ $(mvn -version 2>&1 | head -1)"

# ── 2. Node.js 22 LTS (NodeSource official apt repo) ─────────────────
NODE_MAJOR=22
echo ""
echo "[2/10] Installing Node.js ${NODE_MAJOR} LTS (Jod)..."
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
chmod a+r /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] \
https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" \
    > /etc/apt/sources.list.d/nodesource.list
apt-get update -qq
apt-get install -y --no-install-recommends nodejs
echo "      ✓ Node $(node --version) | npm $(npm --version)"

# ── 3. Python 3.12 + pip (Ubuntu 24.04 built-in + pip bootstrap) ─────
echo ""
echo "[3/10] Installing Python 3 + pip..."
apt-get install -y --no-install-recommends python3 python3-pip python3-venv
echo "      ✓ $(python3 --version) | pip $(pip3 --version | awk '{print $2}')"

# ── 4. Docker (Docker official apt repo) ─────────────────────────────
echo ""
echo "[4/10] Installing Docker (latest)..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list
apt-get update -qq
apt-get install -y --no-install-recommends docker-ce docker-ce-cli containerd.io
usermod -aG docker jenkins
echo "      ✓ $(docker --version)"

# ── 5. Trivy 0.69.3 (PINNED — 0.69.4 was supply chain attack) ────────
# WARNING: Do NOT install 0.69.4. It was a malicious release published
# March 19, 2026 via compromised Aqua Security credentials (CVE-2026-33634).
# It exfiltrates secrets from CI/CD pipelines.
# Safe version: 0.69.3
# Ref: https://github.com/aquasecurity/trivy/discussions/10425
TRIVY_VERSION="0.69.3"
echo ""
echo "[5/10] Installing Trivy ${TRIVY_VERSION} (pinned — 0.69.4 was malicious, CVE-2026-33634)..."

ARCH="$(dpkg --print-architecture)"
case "${ARCH}" in
    amd64)  TRIVY_ARCH="64bit" ;;
    arm64)  TRIVY_ARCH="ARM64" ;;
    *)      echo "Unsupported arch: ${ARCH}"; exit 1 ;;
esac

wget -q "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-${TRIVY_ARCH}.deb" \
    -O /tmp/trivy.deb
dpkg -i /tmp/trivy.deb
rm /tmp/trivy.deb
echo "      ✓ $(trivy --version | head -1)"

# ── 6. AWS CLI v2 (AWS official installer — always latest) ───────────
echo ""
echo "[6/10] Installing AWS CLI v2..."

ARCH="$(uname -m)"
case "${ARCH}" in
    x86_64)  AWS_ARCH="x86_64"  ;;
    aarch64) AWS_ARCH="aarch64" ;;
    *)       echo "Unsupported arch: ${ARCH}"; exit 1 ;;
esac

curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip" \
    -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp/
/tmp/aws/install
rm -rf /tmp/awscliv2.zip /tmp/aws
echo "      ✓ $(aws --version)"

# ── 7. kubectl 1.35 (Kubernetes official apt repo) ───────────────────
echo ""
echo "[7/10] Installing kubectl 1.35..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key \
    | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
chmod a+r /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /" \
    > /etc/apt/sources.list.d/kubernetes.list
apt-get update -qq
apt-get install -y --no-install-recommends kubectl
echo "      ✓ $(kubectl version --client)"

# ── 8. Helm v4.1.4 (Helm official script — explicit version pin) ──────
# NOTE: get-helm-3 script supports v4 installs when DESIRED_VERSION is set.
# Do NOT use bare `curl | bash` — it installs v3 by default.
HELM_VERSION="v4.1.4"
echo ""
echo "[8/10] Installing Helm ${HELM_VERSION}..."
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    | DESIRED_VERSION="${HELM_VERSION}" bash
echo "      ✓ $(helm version --short)"

# ── 9. Terraform 1.14.x (HashiCorp official apt repo) ────────────────
# Note: 1.15.0-rc2 is release candidate only — latest stable is 1.14.x
echo ""
echo "[9/10] Installing Terraform (latest stable 1.14.x)..."
wget -qO - https://apt.releases.hashicorp.com/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/hashicorp-archive-keyring.gpg
chmod a+r /etc/apt/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/hashicorp.list
apt-get update -qq
apt-get install -y --no-install-recommends terraform
echo "      ✓ $(terraform version | head -1)"

# ── 10. Ansible core 2.20 (official PPA — latest stable) ─────────────
# Note: ansible PPA installs latest available (currently core 2.20.x).
# core 2.20 is the current stable, EOL May 2027.
# core 2.18 reached EOL May 2026 — do not pin to it.
echo ""
echo "[10/10] Installing Ansible core 2.20..."
add-apt-repository -y ppa:ansible/ansible
apt-get update -qq
apt-get install -y --no-install-recommends ansible
echo "       ✓ $(ansible --version | head -1)"

# ── Cleanup ───────────────────────────────────────────────────────────
apt-get clean
rm -rf /var/lib/apt/lists/*

echo ""
echo "================================================================"
echo " ✓ All CI/CD pipeline tools installed"
echo ""
echo "   Maven      : $(mvn -version 2>&1 | head -1)"
echo "   Node.js    : $(node --version)"
echo "   npm        : $(npm --version)"
echo "   Python     : $(python3 --version)"
echo "   Docker     : $(docker --version)"
echo "   Trivy      : $(trivy --version | head -1)"
echo "   AWS CLI    : $(aws --version)"
echo "   kubectl    : $(kubectl version --client 2>/dev/null | head -1)"
echo "   Helm       : $(helm version --short)"
echo "   Terraform  : $(terraform version | head -1)"
echo "   Ansible    : $(ansible --version | head -1)"
echo "================================================================"
