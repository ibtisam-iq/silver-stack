#!/bin/bash
# =============================================================================
# Install Docker CE — official Docker apt repo
# https://docs.docker.com/engine/install/ubuntu/
# Enables docker.service via systemd (starts on VM boot, not during build)
# Adds $USER to docker group (no sudo needed at runtime)
# =============================================================================
set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_phase() { echo -e "\n${BLUE}=== $1 ===${NC}\n"; }

log_phase "Docker CE: adding official apt repo"

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list

log_phase "Docker CE: installing packages"

apt-get update
apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin
apt-get clean && rm -rf /var/lib/apt/lists/*

log_phase "Docker CE: post-install configuration"

# Write daemon config (registry mirror for faster pulls)
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'EOF'
{
  "registry-mirrors": ["https://mirror.gcr.io"]
}
EOF

# Enable docker.service — starts automatically when VM boots via systemd
systemctl enable docker
log_info "docker.service enabled"

# Bash completion — system-wide
docker completion bash > /etc/bash_completion.d/docker
log_info "bash completion installed"

# Add user to docker group — no sudo needed at runtime
usermod -aG docker "${USER}"
log_info "user '${USER}' added to docker group"

log_info "============================================"
log_info "Docker CE installed successfully."
log_info "============================================"
