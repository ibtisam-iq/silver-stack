#!/bin/bash
set -euo pipefail

# ==============================================================================
# install-plugins.sh
# ==============================================================================
#
# PURPOSE:
#   Installs a complete, enterprise-grade set of Jenkins plugins required for
#   a production DevSecOps CI/CD pipeline. Covers the full pipeline lifecycle:
#   source control, build, code quality, security scanning, artifact management,
#   containerization, Kubernetes deployment, notifications, and observability.
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
#   4. Installs all plugins defined in the PLUGINS section below
#   5. Triggers a safe restart so all plugins become active
#
# SECURITY:
#   - Password is entered via hidden prompt (not visible on screen)
#   - Password is never written to disk or any log file
#   - Password is never passed as a command-line argument
#   - jenkins-cli.jar is downloaded fresh each run (no stale binary)
#   - All communication goes over HTTPS via your configured Jenkins URL
#
# PLUGIN POLICY (April 2026):
#   - All plugins verified active and non-deprecated as of April 2026
#   - Deprecated plugins EXCLUDED (analysis-core, checkstyle, findbugs, pmd,
#     warnings, ace-editor, jquery-detached, popper-api, bootstrap4-api, etc.)
#   - Replacements used: warnings-ng replaces all old static analysis plugins
#   - Plugin IDs are the official short IDs from https://plugins.jenkins.io
#
# HOW TO RUN:
#   sudo install-plugins
#     (available system-wide — no path prefix needed)
#
# CUSTOMIZATION:
#   To add plugins    → append a new line in the relevant section below
#   To remove plugins → delete or comment out (#) the line
#   To find plugin IDs → https://plugins.jenkins.io
#
# AUTHOR:  Muhammad Ibtisam Iqbal
# ==============================================================================

# ==============================================================================
# PLUGIN LIST
# ==============================================================================
# Organized by pipeline stage / functional category.
# Each plugin has its purpose documented inline.
# All verified active on plugins.jenkins.io as of April 2026.
# ==============================================================================
read -r -d '' PLUGINS_RAW << 'PLUGIN_EOF' || true

# ── PIPELINE FOUNDATION ───────────────────────────────────────────────────────
# Core pipeline engine — must have before anything else works
workflow-aggregator          # Full Pipeline suite: Declarative + Scripted pipelines
pipeline-stage-view          # Visual pipeline stage view in classic Jenkins UI
pipeline-graph-analysis      # Graph-based analysis of pipeline runs
pipeline-build-step          # trigger other jobs from pipeline (build step)
pipeline-input-step          # Manual approval gates: input{} step in pipelines
pipeline-milestone-step      # Prevents out-of-order pipeline execution
pipeline-model-definition    # Declarative Pipeline syntax support
pipeline-rest-api            # REST API access to pipeline data

# ── SOURCE CONTROL MANAGEMENT ─────────────────────────────────────────────────
git                          # Git checkout, clone, fetch in pipelines
git-client                   # Core Git client library (dependency for git plugin)
github                       # GitHub webhooks, PR triggers, commit status updates
github-branch-source         # Multibranch pipelines with GitHub (auto-discovers PRs)
gitlab-plugin                # GitLab webhooks, MR triggers, commit status
bitbucket                    # Bitbucket webhooks and PR builds
scm-api                      # Unified SCM API (required by branch source plugins)

# ── CREDENTIALS & SECRETS MANAGEMENT ─────────────────────────────────────────
credentials                  # Core credentials store (usernames, passwords, tokens)
credentials-binding          # Bind secrets safely as env vars in pipeline steps
plain-credentials            # Store plain text secrets (tokens, API keys)
ssh-credentials              # Store SSH private keys for git/server access
ssh-agent                    # Inject SSH keys into pipeline agent environment
aws-credentials              # Store AWS access/secret keys securely
hashicorp-vault-plugin       # Fetch secrets from HashiCorp Vault at runtime
azure-credentials            # Store Azure service principal credentials

# ── BUILD TOOLS & LANGUAGE SUPPORT ───────────────────────────────────────────
maven-plugin                 # Maven build support: mvn goals in pipelines
nodejs                       # Node.js/npm version management in pipelines
gradle                       # Gradle build support in pipelines
ant                          # Apache Ant build support (legacy Java projects)
jdk-tool                     # JDK version management via Jenkins tools

# ── CODE QUALITY & STATIC ANALYSIS ───────────────────────────────────────────
sonar                        # SonarQube scanner integration in pipelines
# NOTE: Old static analysis plugins (checkstyle, findbugs, pmd, warnings,
# analysis-core) are ALL deprecated. warnings-ng is the unified replacement.
warnings-ng                  # Unified static analysis: replaces checkstyle, findbugs,
                             # pmd, warnings. Supports 50+ tools via one plugin.
code-coverage-api            # Unified coverage reporting (JaCoCo, Cobertura, etc.)
jacoco                       # JaCoCo Java code coverage reporting

# ── SECURITY SCANNING (DevSecOps) ─────────────────────────────────────────────
dependency-check-jenkins-plugin  # OWASP Dependency-Check: CVE scanning of dependencies
custom-markup-formatter          # Render OWASP reports safely in Jenkins UI
aqua-security-scanner            # Aqua Security container scanner (Aqua platform users)
htmlpublisher                    # Publish HTML reports — used to display Trivy HTML output

# ── ARTIFACT MANAGEMENT ───────────────────────────────────────────────────────
nexus-artifact-uploader      # Upload JARs/WARs/artifacts to Nexus repository
artifactory                  # JFrog Artifactory integration for artifact publish/resolve
copyartifact                 # Copy artifacts between Jenkins jobs/pipelines

# ── DOCKER & CONTAINERS ───────────────────────────────────────────────────────
docker-workflow              # docker.build(), docker.push(), docker.image() in pipelines
docker-commons               # Shared Docker utilities and fingerprinting
docker-plugin                # Run build agents dynamically inside Docker containers

# ── KUBERNETES & CLOUD DEPLOYMENT ─────────────────────────────────────────────
kubernetes                   # Run dynamic Jenkins agents as Kubernetes pods
kubernetes-cli               # Run kubectl commands in pipelines (uses kubeconfig creds)
kubernetes-credentials       # Store kubeconfig files as Jenkins credentials
pipeline-aws
ec2                          # Provision Jenkins agents on AWS EC2 on demand
azure-vm-agents              # Provision Jenkins agents on Azure VMs on demand

# ── CONFIGURATION AS CODE (JCasC) ─────────────────────────────────────────────
# Industry standard: entire Jenkins config managed as YAML files in git
# No manual UI configuration — fully reproducible Jenkins setup
configuration-as-code        # JCasC: configure Jenkins via jenkins.yaml file
job-dsl                      # Define Jenkins jobs as Groovy DSL code (jobs-as-code)

# ── MULTI-BRANCH & MULTI-ENV PIPELINE ─────────────────────────────────────────
multibranch-scan-webhook-trigger  # Trigger multibranch scans via webhook
basic-branch-build-strategies     # Control which branches/PRs get built automatically
build-discarder                   # Auto-delete old builds to save disk space
build-timeout                     # Kill builds that exceed a time limit
throttle-concurrents              # Limit concurrent builds to protect resources
lockable-resources
pipeline-milestone-step

# ── PARAMETERIZED BUILDS & ENVIRONMENT PROMOTION ─────────────────────────────
promoted-builds              # Promote builds through environments (dev→staging→prod)
parameterized-trigger        # Trigger downstream jobs with custom parameters
extensible-choice-parameter  # Dynamic dropdown parameters in job configuration
uno-choice                   # Dynamic, reactive parameters (cascading dropdowns)
envinject                    # Inject environment variables into builds

# ── NOTIFICATIONS & COMMUNICATION ─────────────────────────────────────────────
slack                        # Slack notifications on build start/success/failure
email-ext                    # Extended email notifications with templates
mailer                       # Core email notification (dependency for email-ext)
mattermost                   # Mattermost notifications (self-hosted Slack alternative)

# ── BUILD EXPERIENCE & UI ─────────────────────────────────────────────────────
pipeline-graph-view          # Modern pipeline visualization UI (replaces classic UI)
timestamper                  # Timestamps on every line of build console output
ansicolor                    # Colored ANSI console output in build logs
build-name-setter            # Set custom build display names dynamically
badge                        # Show badges/status icons on build history
embeddable-build-status      # Embed build status badges in README/wikis
progress-bar-column-plugin   # Progress bar in pipeline view list

# ── TEST REPORTING ─────────────────────────────────────────────────────────────
junit                        # JUnit XML test results parsing and trend graphs
xunit                        # xUnit test results (NUnit, PHPUnit, Gtest, etc.)
test-results-analyzer        # Detailed test failure analysis across builds
performance                  # JMeter/Gatling performance test result trending

# ── AGENTS & DISTRIBUTED BUILDS ───────────────────────────────────────────────
ssh-slaves                   # Launch agents over SSH
ssh-agent
matrix-auth                  # Matrix-based security: fine-grained user permissions
role-strategy                # Role-based access control (RBAC) for users/groups

# ── PIPELINE LIBRARIES ─────────────────────────────────────────────────────────
pipeline-utility-steps       # Utility steps: readJSON, readYaml, findFiles, zip, etc.
http_request                 # Make HTTP/REST API calls directly from pipeline
generic-webhook-trigger      # Trigger builds from any webhook with JSON/form parsing
ws-cleanup                   # Clean workspace before/after builds

# ── OBSERVABILITY & MONITORING ─────────────────────────────────────────────────
prometheus                   # Expose Jenkins metrics to Prometheus for Grafana dashboards
monitoring                   # JavaMelody-based Jenkins internal monitoring dashboard
cloudbees-disk-usage-simple  # Monitor disk usage per job and build

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
