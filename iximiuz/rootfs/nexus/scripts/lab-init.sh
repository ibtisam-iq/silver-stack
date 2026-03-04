#!/bin/bash
set -euo pipefail

#######################################################################
# Nexus Lab Runtime Initialization
#
# Runs once per boot via systemd oneshot service (lab-init.service)
#
# Author: Muhammad Ibtisam Iqbal
#######################################################################

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

log "Starting Nexus lab runtime initialization..."

# SSH host keys
if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
    log "Generating SSH host keys..."
    ssh-keygen -A
    log "✓ SSH host keys generated"
else
    log "SSH host keys already exist"
fi

mkdir -p /run/sshd
chmod 755 /run/sshd
log "✓ /run/sshd created"

mkdir -p /run/nginx
log "✓ /run/nginx created"

# Nexus data dir permissions (wiped on tmpfs containers)
if [ -d /opt/sonatype-work ]; then
    chown -R nexus:nexus /opt/sonatype-work
    log "✓ Nexus data dir permissions set"
fi

if [ -d /opt/nexus ]; then
    chown -R nexus:nexus /opt/nexus
    log "✓ Nexus home permissions set"
fi

# JVM user prefs dir — must exist and be nexus-owned at every boot
# sonatype-work may be on tmpfs or remounted, so recreate it here
mkdir -p /opt/sonatype-work/jvm-prefs
chown nexus:nexus /opt/sonatype-work/jvm-prefs
log "✓ JVM user prefs dir ready"

log "✓ Initialization complete. systemd will now start services."
