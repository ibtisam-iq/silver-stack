#!/bin/bash
set -euo pipefail
#######################################################################
# install-desktop.sh
# Installs XFCE4 desktop, TigerVNC, PipeWire audio, and Mozilla Firefox
# Called at Docker build time — no systemd running
# Author: Muhammad Ibtisam Iqbal
#######################################################################

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

log "==> Installing XFCE4 desktop environment..."
apt-get update -y
apt-get install -y \
    xfce4 xfce4-goodies \
    tigervnc-standalone-server \
    tigervnc-common \
    dbus-x11 \
    x11-xserver-utils
log "✓ XFCE4 installed"

log "==> Installing PipeWire audio stack..."
apt-get install -y \
    pipewire \
    pipewire-pulse \
    pipewire-audio \
    wireplumber \
    pipewire-alsa
log "✓ PipeWire audio installed"

log "==> Installing XRDP..."
apt-get install -y xrdp
log "✓ XRDP installed"

log "==> Installing Mozilla Firefox from official apt repo..."
snap remove firefox 2>/dev/null || true
apt-get remove --purge -y firefox 2>/dev/null || true

install -d -m 0755 /etc/apt/keyrings
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- \
    | tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null

echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] \
https://packages.mozilla.org/apt mozilla main" \
    | tee /etc/apt/sources.list.d/mozilla.list > /dev/null

echo -e "Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000" \
    | tee /etc/apt/preferences.d/mozilla > /dev/null

apt-get update -y
apt-get install -y firefox
log "✓ Mozilla Firefox installed"
