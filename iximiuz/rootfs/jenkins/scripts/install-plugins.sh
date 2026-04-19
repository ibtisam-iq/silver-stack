#!/bin/bash
# ==============================================================================
# install-plugins.sh
# ==============================================================================
#
# PURPOSE:
#   Installs a curated set of Jenkins plugins required for a production-grade
#   CI/CD pipeline. Uses the official Jenkins CLI (jenkins-cli.jar) over
#   WebSocket to avoid reverse proxy CSRF/origin issues.
#
# WHEN TO RUN:
#   Run this script ONCE after Jenkins is fully set up:
#     1. Jenkins is running and accessible via browser
#     2. You have completed the initial setup wizard
#        (entered initial admin password, created admin user)
#     3. Jenkins URL is configured:
#        Manage Jenkins → System → Jenkins URL → Save
#
# HOW IT WORKS:
#   1. Prompts for Jenkins URL, username, and password interactively
#   2. Auto-detects Jenkins URL from config file if already set
#   3. Downloads jenkins-cli.jar from your Jenkins instance
#   4. Installs all plugins defined in PLUGINS list below
#   5. Triggers a safe restart so plugins become active
#
# SECURITY:
#   - Password is entered via hidden prompt (not visible on screen)
#   - Password is never written to disk or any log file
#   - Password is never passed as a command-line argument
#   - jenkins-cli.jar is downloaded fresh each run (no stale binary)
#   - All communication goes over HTTPS via your configured Jenkins URL
#
# CUSTOMIZATION:
#   To add or remove plugins, edit the PLUGINS list in the
#   "PLUGIN LIST" section below. Use the plugin short ID, not the
#   display name. Find plugin IDs at: https://plugins.jenkins.io
#
# USAGE:
#   sudo bash /opt/jenkins-scripts/install-jenkins-plugins.sh
#
# AUTHOR:  Muhammad Ibtisam Iqbal
# VERSION: 1.0.0 — April 2026
# ==============================================================================

set -euo pipefail

# ==============================================================================
# PLUGIN LIST
# ==============================================================================
# Format : one plugin short ID per line
# Add    : append a new line with the plugin ID
# Remove : delete or comment out (#) the line
# Find   : https://plugins.jenkins.io
# ==============================================================================
read -r -d '' PLUGINS_RAW << 'PLUGIN_EOF' || true
# --- Pipeline ---
workflow-aggregator          # Declarative + Scripted pipeline support

# --- Source Control ---
git                          # Git checkout in pipelines
github                       # GitHub webhooks and PR triggers

# --- Build Tools ---
maven-plugin                 # Maven build support in pipelines

# --- Code Quality ---
sonar                        # SonarQube scanner stage in pipelines

# --- Artifact Management ---
nexus-artifact-uploader      # Push JARs/WARs to Nexus repository

# --- Docker ---
docker-workflow              # docker.build, docker.push in pipelines
docker-commons               # Shared Docker utilities

# --- Credentials & Security ---
credentials-binding          # Bind secrets safely in pipeline steps
ssh-agent                    # SSH key injection for git tag / deploy steps

# --- Security Scanning ---
dependency-check-jenkins-plugin  # OWASP CVE scanning for dependencies

# --- Build Experience ---
timestamper                  # Timestamps on every build log line
ansicolor                    # Colored console output in build logs
PLUGIN_EOF

# Parse plugin list: strip comments and blank lines
mapfile -t PLUGINS < <(echo "${PLUGINS_RAW}" | sed 's/#.*//' | grep -v '^\s*$' | awk '{print $1}') || true

# ==============================================================================
# BANNER
# ==============================================================================
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           Jenkins Plugin Installer — SilverStack             ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  This script installs ${#PLUGINS[@]} curated plugins via Jenkins CLI.    ║"
echo "║                                                              ║"
echo "║  PRE-REQUISITES (must be done before running this):          ║"
echo "║    ✓ Jenkins setup wizard completed                          ║"
echo "║    ✓ Admin username and password created                     ║"
echo "║    ✓ Jenkins URL set in Manage Jenkins → System              ║"
echo "║                                                              ║"
echo "║  SECURITY NOTE:                                              ║"
echo "║    Your password will be entered via hidden prompt.          ║"
echo "║    It is never stored on disk or shown on screen.            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ==============================================================================
# STEP 1 — JENKINS URL
# ==============================================================================
echo "── Step 1 of 4: Jenkins URL ─────────────────────────────────────"
echo ""

LOCATION_CONFIG="/var/lib/jenkins/.jenkins/jenkins.model.JenkinsLocationConfiguration.xml"
DETECTED_URL=""

if [[ -f "${LOCATION_CONFIG}" ]]; then
    DETECTED_URL=$(grep -oP '(?<=<jenkinsUrl>).*(?=</jenkinsUrl>)' "${LOCATION_CONFIG}" 2>/dev/null || true)
    DETECTED_URL="${DETECTED_URL%/}"
fi

if [[ -n "${DETECTED_URL}" ]]; then
    echo "  Auto-detected Jenkins URL: ${DETECTED_URL}"
    echo "  (This was read from jenkins.model.JenkinsLocationConfiguration.xml)"
    echo ""
    read -r -p "  Press Enter to use this URL, or type a different one: " INPUT_URL
    JENKINS_URL="${INPUT_URL:-${DETECTED_URL}}"
else
    echo "  Could not auto-detect Jenkins URL."
    echo "  Please enter the URL Jenkins is accessible at."
    echo "  Examples:"
    echo "    https://jenkins.yourdomain.com"
    echo "    http://localhost:8080"
    echo ""
    read -r -p "  Jenkins URL: " JENKINS_URL
    while [[ -z "${JENKINS_URL}" ]]; do
        echo "  ✗ URL cannot be empty. Please enter the Jenkins URL."
        read -r -p "  Jenkins URL: " JENKINS_URL
    done
fi

JENKINS_URL="${JENKINS_URL%/}"
echo ""
echo "  ✓ Using Jenkins URL: ${JENKINS_URL}"

# ==============================================================================
# STEP 2 — USERNAME
# ==============================================================================
echo ""
echo "── Step 2 of 4: Admin Username ──────────────────────────────────"
echo ""
echo "  Enter the Jenkins admin username you created during setup."
echo "  (Press Enter to use default: admin)"
echo ""
read -r -p "  Username [admin]: " JENKINS_USER
JENKINS_USER="${JENKINS_USER:-admin}"
echo "  ✓ Using username: ${JENKINS_USER}"

# ==============================================================================
# STEP 3 — PASSWORD
# ==============================================================================
echo ""
echo "── Step 3 of 4: Admin Password ──────────────────────────────────"
echo ""
echo "  Enter the password for user '${JENKINS_USER}'."
echo "  Your input will be hidden — nothing will appear as you type."
echo ""

JENKINS_PASS=""
while [[ -z "${JENKINS_PASS}" ]]; do
    read -r -s -p "  Password: " JENKINS_PASS
    echo ""
    if [[ -z "${JENKINS_PASS}" ]]; then
        echo "  ✗ Password cannot be empty. Please try again."
        echo ""
    fi
done
echo "  ✓ Password received (hidden)"

# ==============================================================================
# STEP 4 — INSTALL PLUGINS
# ==============================================================================
echo ""
echo "── Step 4 of 4: Installing Plugins ──────────────────────────────"
echo ""
echo "  The following ${#PLUGINS[@]} plugins will be installed:"
echo ""
printf '    %-40s\n' "${PLUGINS[@]}"
echo ""

# Confirm before proceeding
read -r -p "  Proceed with installation? [Y/n]: " CONFIRM
CONFIRM="${CONFIRM:-Y}"
if [[ ! "${CONFIRM}" =~ ^[Yy]$ ]]; then
    echo ""
    echo "  Aborted. No changes made."
    exit 0
fi

echo ""

# ── Check Jenkins is reachable ────────────────────────────────────────
echo "  Checking Jenkins availability..."
until curl -fsSL "${JENKINS_URL}/login" > /dev/null 2>&1; do
    echo "  Jenkins not ready yet — retrying in 5s..."
    sleep 5
done
echo "  ✓ Jenkins is reachable"

# ── Download jenkins-cli.jar ──────────────────────────────────────────
CLI_JAR="/tmp/jenkins-cli.jar"
echo ""
echo "  Downloading jenkins-cli.jar from ${JENKINS_URL}..."
echo "  (This is downloaded fresh each run to match your Jenkins version)"
curl -fsSL "${JENKINS_URL}/jnlpJars/jenkins-cli.jar" -o "${CLI_JAR}"
echo "  ✓ jenkins-cli.jar downloaded"

# ── Run install-plugin ────────────────────────────────────────────────
echo ""
echo "  Installing plugins via Jenkins CLI over WebSocket..."
echo "  (WebSocket mode is used to bypass reverse proxy origin checks)"
echo ""

java -jar "${CLI_JAR}" \
    -s "${JENKINS_URL}" \
    -webSocket \
    -auth "${JENKINS_USER}:${JENKINS_PASS}" \
    install-plugin "${PLUGINS[@]}"

echo ""
echo "  ✓ All ${#PLUGINS[@]} plugins installed successfully"

# ── Safe restart ──────────────────────────────────────────────────────
echo ""
echo "  Triggering Jenkins safe-restart to activate plugins..."
echo "  (safe-restart waits for running builds to finish before restarting)"

java -jar "${CLI_JAR}" \
    -s "${JENKINS_URL}" \
    -webSocket \
    -auth "${JENKINS_USER}:${JENKINS_PASS}" \
    safe-restart

# ── Cleanup ───────────────────────────────────────────────────────────
rm -f "${CLI_JAR}"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    ✓ Installation Complete                   ║"
echo "║                                                              ║"
echo "║  Jenkins is restarting. Wait ~30 seconds then reload UI.     ║"
echo "║  All ${#PLUGINS[@]} plugins will be active after restart.                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
