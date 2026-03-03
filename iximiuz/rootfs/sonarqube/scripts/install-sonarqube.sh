#!/bin/bash
set -euo pipefail

#######################################################################
# SonarQube Installation Script
#
# Installs Java 21 and SonarQube 26.2 Community Edition.
#
# Arguments:
#   PORT - SonarQube HTTP port (default: 9000)
#
# Author: Muhammad Ibtisam Iqbal
#######################################################################

SONARQUBE_PORT=${1:-9000}
SONARQUBE_VERSION="26.2.0.119303"
DOWNLOAD_URL="https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${SONARQUBE_VERSION}.zip"

if ! [[ "${SONARQUBE_PORT}" =~ ^[0-9]+$ ]] || \
   [ "${SONARQUBE_PORT}" -lt 1 ] || \
   [ "${SONARQUBE_PORT}" -gt 65535 ]; then
    echo "ERROR: Invalid port: ${SONARQUBE_PORT}"
    echo "Port must be a number between 1 and 65535"
    exit 1
fi

echo "Installing Java 21..."
apt-get update
apt-get install -y --no-install-recommends openjdk-21-jdk
java -version

echo "Downloading SonarQube ${SONARQUBE_VERSION}..."
cd /opt
wget -q "${DOWNLOAD_URL}"
unzip -q "sonarqube-${SONARQUBE_VERSION}.zip"
mv "sonarqube-${SONARQUBE_VERSION}" sonarqube
rm "sonarqube-${SONARQUBE_VERSION}.zip"

echo "Creating sonar system user..."
useradd --system --no-create-home --shell /bin/bash sonar

echo "Setting up SonarQube directories..."
chown -R sonar:sonar /opt/sonarqube
chmod -R 755 /opt/sonarqube

mkdir -p /opt/sonarqube/data
mkdir -p /opt/sonarqube/temp
mkdir -p /opt/sonarqube/logs
chown -R sonar:sonar /opt/sonarqube/{data,temp,logs}

echo "Configuring system limits for Elasticsearch..."
cat >> /etc/sysctl.conf <<EOF
vm.max_map_count=524288
fs.file-max=131072
EOF

cat >> /etc/security/limits.conf <<EOF
sonar soft nofile 131072
sonar hard nofile 131072
sonar soft nproc 8192
sonar hard nproc 8192
EOF

echo "Verifying sonar user..."
id sonar

echo ""
echo "✓ SonarQube installed successfully"
echo "  Version  : ${SONARQUBE_VERSION}"
echo "  Home     : /opt/sonarqube"
echo "  User     : sonar"
echo "  Group    : sonar"
echo "  HTTP Port: ${SONARQUBE_PORT}"
