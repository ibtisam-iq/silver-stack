#!/bin/bash
set -euo pipefail
#######################################################################
# configure-xrdp.sh
# Configures XRDP for XFCE4 sessions:
#   - Sets key.pem permissions
#   - Writes startwm.sh (already copied via Dockerfile COPY)
#   - Writes .xsession for the RDP desktop user
#   - Fixes /run/xrdp tmpfiles for boot persistence
#   - Sets security_layer=rdp (avoids SSL mismatch with guacd)
# Arguments:
#   $1 - RDP_USER  (desktop user, e.g. devuser)
#   $2 - RDP_PORT  (default: 3389)
# Author: Muhammad Ibtisam Iqbal
#######################################################################

RDP_USER="${1:?RDP_USER required}"
RDP_PORT="${2:-3389}"

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

log "==> Configuring XRDP permissions..."
chmod 640 /etc/xrdp/key.pem
chown root:xrdp /etc/xrdp/key.pem
adduser xrdp ssl-cert 2>/dev/null || true
chmod +x /etc/xrdp/startwm.sh
log "✓ XRDP key.pem and startwm.sh configured"

log "==> Setting xrdp security_layer=rdp (required for guacd compatibility)..."
sed -i 's/^security_layer=.*/security_layer=rdp/' /etc/xrdp/xrdp.ini
log "✓ security_layer=rdp set"

log "==> Ensuring RDP user '${RDP_USER}' exists..."
id "${RDP_USER}" &>/dev/null || useradd -m -s /bin/bash "${RDP_USER}"
usermod -aG sudo "${RDP_USER}" 2>/dev/null || true
log "✓ User '${RDP_USER}' ensured"

log "==> Creating .xsession for ${RDP_USER}..."
mkdir -p "/home/${RDP_USER}"
cat > "/home/${RDP_USER}/.xsession" << 'INNEREOF'
#!/bin/bash
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=XFCE
export DISPLAY=${DISPLAY:-:10.0}
exec dbus-launch --exit-with-session startxfce4
INNEREOF
chmod +x "/home/${RDP_USER}/.xsession"
chown "${RDP_USER}:${RDP_USER}" "/home/${RDP_USER}/.xsession"
log "✓ .xsession written for ${RDP_USER}"

log "==> Configuring /run/xrdp tmpfiles (boot persistence)..."
mkdir -p /run/xrdp
chown xrdp:xrdp /run/xrdp
chmod 755 /run/xrdp
echo "d /run/xrdp 0755 xrdp xrdp -" | tee /etc/tmpfiles.d/xrdp.conf
mkdir -p /tmp/.xrdp
chmod 1777 /tmp/.xrdp
log "✓ /run/xrdp tmpfiles configured"
