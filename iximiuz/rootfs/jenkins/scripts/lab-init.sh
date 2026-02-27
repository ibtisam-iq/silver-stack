#!/bin/bash
set -euo pipefail

#######################################################################
# Jenkins Lab Runtime Initialization
#
# Runs once per boot via systemd oneshot service (lab-init.service)
#
# Author: Muhammad Ibtisam Iqbal
#######################################################################

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

log "Starting Jenkins lab runtime initialization..."

# SSH host keys (base image deletes them; generate fresh per machine)
if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
    log "Generating SSH host keys..."
    ssh-keygen -A
    log "✓ SSH host keys generated"
else
    log "SSH host keys already exist"
fi

# /run/sshd — wiped on every boot by tmpfs, sshd requires it
mkdir -p /run/sshd
chmod 755 /run/sshd
log "✓ /run/sshd created"

# Runtime directories for nginx
mkdir -p /run/nginx
log "✓ /run/nginx created"

# Jenkins home permissions
if [ -d /var/lib/jenkins ]; then
    chown -R jenkins:jenkins /var/lib/jenkins
    chmod 755 /var/lib/jenkins
    log "✓ Jenkins home permissions set"
fi

log "✓ Initialization complete. systemd will now start services."
