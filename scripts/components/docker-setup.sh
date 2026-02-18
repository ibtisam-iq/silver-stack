#!/usr/bin/env bash
# =====================================================================
# infra-bootstrap — Component Installer: Docker (V3.6)
# Author: Muhammad Ibtisam Iqbal
# License: MIT
# =====================================================================

set -Eeuo pipefail
IFS=$'\n\t'

# ================= Load common.sh =================
COMMON_URL="https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/lib/common.sh"
tmp="$(mktemp)"
curl -fsSL "$COMMON_URL" -o "$tmp" || { echo "FATAL: common.sh fetch failed"; exit 1; }
source "$tmp"
rm -f "$tmp"

banner "Installing: Docker"

# ================= Preflight ======================
section "Running preflight checks..."
PRE_URL="https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/system-checks/preflight.sh"

if ! bash <(curl -fsSL "$PRE_URL") >/dev/null 2>&1; then
    error "Preflight failed — aborting Docker installation"
fi
ok "Preflight passed."
blank

# ================= Helper functions ================
docker_installed() { command -v docker >/dev/null 2>&1; }
docker_active()   { systemctl is-active --quiet docker; }

# ================= Existing Install Logic ===========
if docker_installed; then
    warn "Docker already installed."

    # Normalize versions reliably
    v_docker=$(docker --version | awk '{print $3}' | tr -d ',' | sed 's/^v//')
    v_containerd=$(containerd --version 2>/dev/null | awk '{print $3}' | sed 's/^v//')
    v_runc=$(runc --version 2>/dev/null | awk '{print $3}' | sed 's/^v//')

    # Docker Compose version
    if docker compose version &>/dev/null; then
        v_compose=$(docker compose version | awk '{print $4}' | sed 's/^v//')
    else
        v_compose="[ NOT INSTALLED ]"
    fi

    # If installed but service is OFF → fix it
    if ! docker_active; then
        section "Docker present but daemon not running — repairing..."
        systemctl enable docker >/dev/null 2>&1 || warn "enable failed"
        systemctl start docker  >/dev/null 2>&1 || warn "start failed"
        sleep 1

        docker_active \
            && ok "Docker daemon started successfully" \
            || error "Docker installed but daemon still inactive — manual intervention required"
    else
        ok "Docker daemon already running"
    fi

    # Output final state
    printf " Docker:         %s\n" "$v_docker"
    printf " Containerd:     %s\n" "$v_containerd"
    printf " Runc:           %s\n" "$v_runc"
    printf " Docker Compose: %s\n" "$v_compose"

    footer "Docker validated — no installation performed"
    exit 0
fi

# ================= Install Dependencies ============
section "Installing prerequisites..."
apt-get update -qq
apt-get install -y ca-certificates curl >/dev/null 2>&1 || error "Dependency install failed"
ok "Dependencies ready."
blank

# ================= Install Docker Repo =============
section "Adding Docker repository..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

ok "Repository configured."
blank

# ================= Install Docker ==================
section "Installing Docker..."
apt-get update -qq
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1 \
    || error "Docker installation failed"
ok "Docker installed."
blank

# ================= Enable & Start ==================
section "Starting Docker service..."
systemctl enable docker >/dev/null 2>&1 || warn "enable failed"
systemctl start docker >/dev/null 2>&1 || warn "start failed"
sleep 1

docker_active \
    && ok "Docker daemon running" \
    || error "Docker daemon could not start"
blank

# ================= User Permissions ================
section "Configuring docker user permissions..."
REAL_USER=${SUDO_USER:-$USER}

if id "$REAL_USER" | grep -q docker; then
    ok "$REAL_USER already in docker group"
else
    usermod -aG docker "$REAL_USER"
    ok "Added $REAL_USER to docker group (relogin required)"
fi
blank

# ================= Version Summary ==================
v_docker=$(docker --version | awk '{print $3}' | tr -d ',' | sed 's/^v//')
v_containerd=$(containerd --version | awk '{print $3}' | sed 's/^v//')
v_runc=$(runc --version | awk '{print $3}' | sed 's/^v//')

if docker compose version &>/dev/null; then
    v_compose=$(docker compose version | awk '{print $4}' | sed 's/^v//')
else
    v_compose="[ NOT INSTALLED ]"
fi

printf " Docker:         %s\n" "$v_docker"
printf " Containerd:     %s\n" "$v_containerd"
printf " Runc:           %s\n" "$v_runc"
printf " Docker Compose: %s\n" "$v_compose"

footer "Docker installation completed — run 'newgrp docker' or re-login to activate"
exit 0