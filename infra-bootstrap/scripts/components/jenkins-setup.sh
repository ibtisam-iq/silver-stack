#!/usr/bin/env bash
# ============================================================================
# infra-bootstrap — Jenkins Server Installer
# Installs Jenkins LTS + Java 17, enables service, prints access info.
# ============================================================================
set -Eeuo pipefail
IFS=$'\n\t'

LIB_URL="https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/lib/common.sh"
source <(curl -fsSL "$LIB_URL") || { echo "FATAL: unable to load common.sh"; exit 1; }

banner "Installing: Jenkins"

# ───────────────────────────── Preflight & minimal fixes ─────────────────────
info "Running preflight..."
bash <(curl -fsSL "https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main/scripts/system-checks/preflight.sh") >/dev/null 2>&1 && ok "Preflight passed." || error "Preflight failed — aborting."
blank

info "Ensuring minimal system directories exist..."
mkdir -p /usr/share/man/man1 /usr/share/man/man7 /var/cache/jenkins/war || true
ok "Minimal directories ensured."
blank

# ─────────────────────── Idempotency ─────────────────────
if command -v jenkins >/dev/null 2>&1; then
    JVER=$(jenkins --version 2>/dev/null || echo "unknown")
    warn "Jenkins already installed ($JVER)"; hr
    item_ver() { printf " %b•%b %-*s %s\n" "$C_CYAN" "$C_RESET" 20 "$1:" "$2"; }
    item_ver "Jenkins" "$JVER"; hr
    ok "No installation performed"; blank
    exit 0
fi

# ─────────────────────── Java 17 ─────────────────────
section "Installing OpenJDK 17"
java -version >/dev/null 2>&1 && ok "Java already installed" || {
    sudo apt-get update -qq
    sudo apt-get install -yq openjdk-17-jdk-headless >/dev/null 2>&1 || error "Java install failed"
    ok "Java installed"
}
blank

# ─────────────────────── Jenkins repo & install ─────────────────────
section "Configuring Jenkins repository & installing"
sudo mkdir -p /usr/share/keyrings
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc >/dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list >/dev/null
sudo apt-get update -qq
sudo apt-get install -yq jenkins >/dev/null 2>&1 || error "Failed to install Jenkins"
ok "Jenkins installed"
blank

# ─────────────────────── Port handling ─────────────────────
DEFAULT_PORT=8080
JENKINS_PORT="$DEFAULT_PORT"

section "Port Availability Check"
PORT_PROCESS=$(ss -tulnp 2>/dev/null | grep ":${DEFAULT_PORT} " || true)

if [[ -n "$PORT_PROCESS" ]]; then
    warn "Port $DEFAULT_PORT is already in use."
    info "Process using the port:"
    blank
    echo "$PORT_PROCESS" | sed 's/^/   /'
    blank

    echo "Choose an action:"
    echo " 1) Kill the process using port $DEFAULT_PORT"
    echo " 2) Use a different port for Jenkins"
    echo " 3) Ignore (Jenkins may FAIL to start)"
    blank
    exec </dev/tty

    while true; do
        read -rp "Enter choice (1/2/3): " choice
        blank
        case "$choice" in
            1)
                # Smart kill: handles docker-proxy correctly
                if echo "$PORT_PROCESS" | grep -q docker-proxy; then
                    CONTAINER_ID=$(docker ps --filter "publish=8080" --format "{{.ID}}" | head -n1)
                    if [[ -n "$CONTAINER_ID" ]]; then
                        warn "Stopping Docker container using port 8080 ($CONTAINER_ID)"
                        docker kill "$CONTAINER_ID" >/dev/null 2>&1 || docker stop "$CONTAINER_ID" >/dev/null 2>&1
                        ok "Docker container stopped"
                    else
                        warn "Could not identify Docker container – falling back to PID kill"
                    fi
                fi

                # Fallback PID kill (for non-docker cases)
                PIDS=$(echo "$PORT_PROCESS" | awk -F'pid=' '{print $2}' | awk -F',' '{print $1}' | sort -u)
                for pid in $PIDS; do
                    [[ -n "$pid" ]] && kill -9 "$pid" 2>/dev/null && ok "Killed PID $pid" || true
                done
                ok "Port $DEFAULT_PORT freed"
                break
                ;;

            2)
                while true; do
                    read -rp "Enter new port for Jenkins (1024-65535): " NEWPORT
                    blank
                    if [[ "$NEWPORT" =~ ^[0-9]+$ ]] && (( NEWPORT >= 1024 && NEWPORT <= 65535 )); then
                        JENKINS_PORT="$NEWPORT"
                        ok "Jenkins will use port $JENKINS_PORT"
                        break 2
                    else
                        warn "Invalid port. Must be 1024–65535."
                    fi
                done
                ;;

            3)
                warn "Continuing without resolving port conflict — Jenkins may fail."
                break
                ;;

            *) warn "Invalid choice. Enter 1, 2, or 3." ;;
        esac
    done
    blank
else
    ok "Port $DEFAULT_PORT is free."
fi

# ─────────────────────── Apply custom port ─────────────────────
if [[ "$JENKINS_PORT" != "$DEFAULT_PORT" ]] || [[ -n "$PORT_PROCESS" ]]; then
    info "Configuring Jenkins to use port $JENKINS_PORT ..."

    # Fix /etc/default/jenkins
    CONF="/etc/default/jenkins"
    sudo mkdir -p "$(dirname "$CONF")"
    if [[ ! -f "$CONF" ]]; then
        sudo tee "$CONF" >/dev/null <<EOF
HTTP_PORT=$JENKINS_PORT
JENKINS_ARGS="--webroot=/var/cache/jenkins/war --httpPort=\$HTTP_PORT"
EOF
    else
        sudo sed -i -E "s/^#?HTTP_PORT=.*/HTTP_PORT=$JENKINS_PORT/" "$CONF" || echo "HTTP_PORT=$JENKINS_PORT" | sudo tee -a "$CONF" >/dev/null
        sudo sed -i -E 's|^JENKINS_ARGS=.*|JENKINS_ARGS="--webroot=/var/cache/jenkins/war --httpPort=\$HTTP_PORT"|' "$CONF" || \
            echo 'JENKINS_ARGS="--webroot=/var/cache/jenkins/war --httpPort=\$HTTP_PORT"' | sudo tee -a "$CONF" >/dev/null
    fi

    # The real magic: systemd override
    sudo mkdir -p /etc/systemd/system/jenkins.service.d
    sudo tee /etc/systemd/system/jenkins.service.d/override.conf >/dev/null <<EOF
[Service]
Environment="JENKINS_PORT=$JENKINS_PORT"
Environment="JENKINS_OPTS=--httpPort=$JENKINS_PORT"
EOF
    sudo systemctl daemon-reload
    ok "Port $JENKINS_PORT applied via /etc/default/jenkins + systemd override"
fi
blank

# ─────────────────────── Start Jenkins ─────────────────────
section "Starting Jenkins service"
sudo systemctl enable jenkins >/dev/null 2>&1
sudo systemctl restart jenkins >/dev/null 2>&1 || true
sleep 8

systemctl is-active --quiet jenkins && ok "Jenkins service is running" || { warn "Starting Jenkins..."; sudo systemctl start jenkins; }

if ss -tuln | grep -q ":$JENKINS_PORT[[:space:]]"; then
    ok "Jenkins is listening on port $JENKINS_PORT"
else
    warn "Jenkins not listening on $JENKINS_PORT — check 'journalctl -u jenkins'"
fi
blank

# ─────────────────────── Final summary ─────────────────────
section "Access Information"
LOCAL_IP=$(hostname -I | awk '{print $1}')
PUBLIC_IP=$(curl -fsSL ifconfig.me 2>/dev/null || echo "Unavailable")
JVER=$(jenkins --version 2>/dev/null | awk '{print $1}' || echo "unknown")

item_ver() { printf " %b•%b %-*s %s\n" "$C_CYAN" "$C_RESET" 20 "$1:" "$2"; }
hr
item_ver "Jenkins" "$JVER"
item_ver "Port"    "$JENKINS_PORT"
hr
info "Access URLs:"
item_ver "Local"  "http://$LOCAL_IP:$JENKINS_PORT"
item_ver "Public" "http://$PUBLIC_IP:$JENKINS_PORT"
hr

info "Initial Admin Password:"
if [[ -f /var/lib/jenkins/secrets/initialAdminPassword ]]; then
    item_ver "Password" "$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)"
else
    warn "Password file not ready yet — wait 10-20s and refresh"
fi
hr

footer "Jenkins successfully installed and running on port $JENKINS_PORT"
exit 0