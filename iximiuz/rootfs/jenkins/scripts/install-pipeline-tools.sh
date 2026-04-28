#!/bin/bash
set -euo pipefail

# ==============================================================================
# install-pipeline-tools.sh
# ==============================================================================
#
# PURPOSE:
#   Installs all CI/CD pipeline tools required by Jenkins pipelines on this
#   server. These are the actual build/deploy tools that your Jenkinsfile
#   stages will call — Maven for builds, Docker for containers, Trivy for
#   security scanning, Terraform for infrastructure, etc.
#
# WHEN TO RUN:
#   Run this script BEFORE running any Jenkins pipelines.
#   It can be run right after the server starts — no Jenkins setup required.
#   It installs system-level tools, not Jenkins plugins.
#
#   NOTE: This script was intentionally NOT run during docker build to keep
#   the image lean. Run it once after the container is up.
#
# WHAT IT INSTALLS (10 tools):
#   [1]  Maven      3.9.15    — Java build tool (Apache official binary)
#   [2]  Node.js    22 LTS    — JavaScript runtime (NodeSource official repo)
#   [3]  Python     3.12      — Scripting (Ubuntu 24.04 built-in + pip)
#   [4]  Docker     latest    — Container build & run (Docker official repo)
#   [5]  Trivy      0.69.3    — Container/IaC security scanner (PINNED — see below)
#   [6]  AWS CLI    v2        — AWS cloud operations (AWS official installer)
#   [7]  kubectl    1.35      — Kubernetes cluster management
#   [8]  Helm       4.1.4     — Kubernetes package manager
#   [9]  Terraform  1.14.x    — Infrastructure as Code (HashiCorp official repo)
#   [10] Ansible    core 2.20 — Configuration management (official PPA)
#
# SECURITY NOTE — Trivy 0.69.3 (PINNED):
#   Version 0.69.4 was a malicious release published March 19, 2026 via
#   compromised Aqua Security credentials (CVE-2026-33634). It exfiltrated
#   secrets from CI/CD pipelines. This script is pinned to 0.69.3 which is
#   the last verified safe release.
#   Ref: https://github.com/aquasecurity/trivy/discussions/10425
#
# HOW TO RUN:
#   sudo install-pipeline-tools
#     (available system-wide — no path prefix needed)
#
# ESTIMATED TIME: 5-10 minutes depending on network speed.
# REQUIRES: Root/sudo. Ubuntu 24.04. Internet access.
#
# CUSTOMIZATION:
#   To skip a tool, comment out its section below.
#   To pin a different version, change the version variable at the top
#   of each section.
#
# AUTHOR:  Muhammad Ibtisam Iqbal
# ==============================================================================

# ── Banner ────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       Jenkins CI/CD Pipeline Tools Installer                 ║"
echo "║       SilverStack — Ubuntu 24.04 — April 2026                ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Installing 10 tools: Maven, Node.js, Python, Docker,        ║"
echo "║  Trivy, AWS CLI, kubectl, Helm, Terraform, Ansible           ║"
echo "║                                                              ║"
echo "║  All tools are installed from official upstream sources.     ║"
echo "║  Estimated time: 5-10 minutes depending on network speed.    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ── Base dependencies ─────────────────────────────────────────────────
echo "Updating package index and installing base dependencies..."
apt-get update -qq
apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg wget unzip lsb-release \
    software-properties-common apt-transport-https
install -m 0755 -d /etc/apt/keyrings
echo "  ✓ Base dependencies ready"
echo ""

# ── [1/10] Maven ─────────────────────────────────────────────────────
MAVEN_VERSION="3.9.15"
echo "[1/10] Installing Maven ${MAVEN_VERSION}..."
echo "       Source: https://downloads.apache.org/maven (Apache official)"
wget -q "https://downloads.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
    -O /tmp/maven.tar.gz
tar -xzf /tmp/maven.tar.gz -C /opt/
ln -sf /opt/apache-maven-${MAVEN_VERSION} /opt/maven
ln -sf /opt/maven/bin/mvn /usr/local/bin/mvn
rm /tmp/maven.tar.gz
echo "       ✓ $(mvn -version 2>&1 | head -1)"
echo ""

# ── [2/10] Node.js 22 LTS ────────────────────────────────────────────
NODE_MAJOR=22
echo "[2/10] Installing Node.js ${NODE_MAJOR} LTS (Jod — LTS until Apr 2027)..."
echo "       Source: NodeSource official apt repo"
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
chmod a+r /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] \
https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" \
    > /etc/apt/sources.list.d/nodesource.list
apt-get update -qq
apt-get install -y --no-install-recommends nodejs
echo "       ✓ Node $(node --version) | npm $(npm --version)"
echo ""

# ── [3/10] Python 3.12 ───────────────────────────────────────────────
echo "[3/10] Installing Python 3.12 + pip + venv..."
echo "       Source: Ubuntu 24.04 built-in (python3.12 is the system default)"
apt-get install -y --no-install-recommends python3 python3-pip python3-venv
echo "       ✓ $(python3 --version) | pip $(pip3 --version | awk '{print $2}')"
echo ""

# ── [4/10] Docker ────────────────────────────────────────────────────
echo "[4/10] Installing Docker (latest stable)..."
echo "       Source: Docker official apt repo (download.docker.com)"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list
apt-get update -qq
apt-get install -y --no-install-recommends docker-ce docker-ce-cli containerd.io
usermod -aG docker jenkins
echo "       ✓ $(docker --version)"
echo ""

# ── [5/10] Trivy (PINNED — 0.69.4 was malicious) ────────────────────
TRIVY_VERSION="0.69.3"
echo "[5/10] Installing Trivy ${TRIVY_VERSION} (container & IaC security scanner)..."
echo "       Source: GitHub Releases (aquasecurity/trivy)"
echo "       ⚠ PINNED to ${TRIVY_VERSION} — 0.69.4 was a supply-chain attack"
echo "         (CVE-2026-33634, March 19, 2026 — exfiltrated pipeline secrets)"

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
echo "       ✓ $(trivy --version | head -1)"
echo ""

# Trivy cache dir — must exist and be owned by jenkins before any pipeline runs
mkdir -p /var/cache/trivy
chown -R jenkins:jenkins /var/cache/trivy
chmod 755 /var/cache/trivy

# ── [6/10] AWS CLI v2 ────────────────────────────────────────────────
echo "[6/10] Installing AWS CLI v2 (latest)..."
echo "       Source: AWS official installer (awscli.amazonaws.com)"

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
echo "       ✓ $(aws --version)"
echo ""

# ── [7/10] kubectl 1.35 ──────────────────────────────────────────────
echo "[7/10] Installing kubectl 1.35..."
echo "       Source: Kubernetes official apt repo (pkgs.k8s.io)"
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key \
    | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
chmod a+r /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /" \
    > /etc/apt/sources.list.d/kubernetes.list
apt-get update -qq
apt-get install -y --no-install-recommends kubectl
echo "       ✓ $(kubectl version --client 2>/dev/null | head -1)"
echo ""

# ── [8/10] Helm v4.1.4 ───────────────────────────────────────────────
HELM_VERSION="v4.1.4"
echo "[8/10] Installing Helm ${HELM_VERSION}..."
echo "       Source: Helm official install script (raw.githubusercontent.com/helm)"
echo "       NOTE: DESIRED_VERSION is set explicitly — bare script installs v3 by default"
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    | DESIRED_VERSION="${HELM_VERSION}" bash
echo "       ✓ $(helm version --short)"
echo ""

# ── [9/10] Terraform 1.14.x ──────────────────────────────────────────
echo "[9/10] Installing Terraform (latest stable 1.14.x)..."
echo "       Source: HashiCorp official apt repo"
echo "       NOTE: 1.15.0-rc2 is a release candidate only — not production-ready"
wget -qO - https://apt.releases.hashicorp.com/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/hashicorp-archive-keyring.gpg
chmod a+r /etc/apt/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/hashicorp.list
apt-get update -qq
apt-get install -y --no-install-recommends terraform
echo "       ✓ $(terraform version | head -1)"
echo ""

# ── [10/10] Ansible core 2.20 ────────────────────────────────────────
echo "[10/10] Installing Ansible core 2.20..."
echo "        Source: Official Ansible PPA (ppa:ansible/ansible)"
echo "        NOTE: core 2.18 reached EOL May 2026 — 2.20 is current stable (EOL May 2027)"
add-apt-repository -y ppa:ansible/ansible
apt-get update -qq
apt-get install -y --no-install-recommends ansible
echo "        ✓ $(ansible --version | head -1)"
echo ""

# ── Cleanup ───────────────────────────────────────────────────────────
apt-get clean
rm -rf /var/lib/apt/lists/*

# ── Summary ───────────────────────────────────────────────────────────
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              ✓ All Tools Installed Successfully              ║"
echo "╠══════════════════════════════════════════════════════════════╣"
printf "║  %-20s %s\n" "Maven:"     "$(mvn -version 2>&1 | head -1 | cut -d' ' -f1-3)                    ║"
printf "║  %-20s %s\n" "Node.js:"   "$(node --version)                               ║"
printf "║  %-20s %s\n" "npm:"       "$(npm --version)                                 ║"
printf "║  %-20s %s\n" "Python:"    "$(python3 --version)                          ║"
printf "║  %-20s %s\n" "Docker:"    "$(docker --version | cut -d',' -f1)                  ║"
printf "║  %-20s %s\n" "Trivy:"     "$(trivy --version | head -1)                        ║"
printf "║  %-20s %s\n" "AWS CLI:"   "$(aws --version | cut -d' ' -f1-2)          ║"
printf "║  %-20s %s\n" "kubectl:"   "$(kubectl version --client 2>/dev/null | head -1)                ║"
printf "║  %-20s %s\n" "Helm:"      "$(helm version --short)                        ║"
printf "║  %-20s %s\n" "Terraform:" "$(terraform version | head -1)                      ║"
printf "║  %-20s %s\n" "Ansible:"   "$(ansible --version | head -1)                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  You can now run Jenkins pipelines that use these tools."
echo "  Next step: Set up Jenkins, then run:  sudo install-plugins"
echo ""
