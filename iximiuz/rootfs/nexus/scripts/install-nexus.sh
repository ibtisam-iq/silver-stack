#!/bin/bash
set -euo pipefail

#######################################################################
# Nexus Repository Manager Installation Script
#
# Installs OpenJDK 21 and Nexus OSS 3.89.1.
#
# Arguments:
#   PORT - Nexus HTTP port (default: 8081)
#
# Author: Muhammad Ibtisam Iqbal
#######################################################################

NEXUS_PORT=${1:-8081}
NEXUS_VERSION="3.89.1-02"
NEXUS_HOME="/opt/nexus"
NEXUS_DATA="/opt/sonatype-work"

# Detect architecture — Sonatype uses "aarch_64" (with underscore) not "aarch64"
ARCH=$(uname -m)
case "${ARCH}" in
    x86_64)         NEXUS_ARCH="linux-x86_64" ;;
    aarch64|arm64)  NEXUS_ARCH="linux-aarch_64" ;;
    *)
        echo "ERROR: Unsupported architecture: ${ARCH}"
        exit 1
        ;;
esac

DOWNLOAD_URL="https://download.sonatype.com/nexus/3/nexus-${NEXUS_VERSION}-${NEXUS_ARCH}.tar.gz"

echo "Installing Java 21..."
apt-get update
apt-get install -y --no-install-recommends openjdk-21-jdk
java -version
echo "✓ Java 21 installed"

echo ""
echo "Downloading Nexus ${NEXUS_VERSION} (${NEXUS_ARCH})..."
echo "  URL: ${DOWNLOAD_URL}"
cd /opt
curl -fsSL "${DOWNLOAD_URL}" -o nexus.tar.gz

echo "Extracting..."
tar -xzf nexus.tar.gz
mv nexus-${NEXUS_VERSION} nexus
rm nexus.tar.gz
echo "✓ Nexus extracted to ${NEXUS_HOME}"

echo ""
echo "Creating nexus system user..."
useradd --system --no-create-home --shell /bin/bash nexus
echo "✓ nexus user created"

echo ""
echo "Setting up directories and permissions..."
mkdir -p "${NEXUS_DATA}"
chown -R nexus:nexus "${NEXUS_HOME}"
chown -R nexus:nexus "${NEXUS_DATA}"
chmod -R 750 "${NEXUS_HOME}"
chmod -R 750 "${NEXUS_DATA}"
echo "✓ Permissions set"

# Set run_as_user
echo 'run_as_user="nexus"' > "${NEXUS_HOME}/bin/nexus.rc"
echo "✓ run_as_user set to nexus"

# Set port and host in nexus.properties
NEXUS_PROPS="${NEXUS_DATA}/nexus3/etc/nexus.properties"
mkdir -p "$(dirname ${NEXUS_PROPS})"
cat > "${NEXUS_PROPS}" <<EOF
application-port=${NEXUS_PORT}
application-host=0.0.0.0
nexus-args=\${jetty.etc}/jetty.xml,\${jetty.etc}/jetty-http.xml,\${jetty.etc}/jetty-requestlog.xml
nexus-context-path=/
EOF
echo "✓ nexus.properties configured (port: ${NEXUS_PORT})"

# Redirect Java user prefs — nexus has no home dir so JVM can't write ~/.java
NEXUS_VMOPTIONS="${NEXUS_HOME}/bin/nexus.vmoptions"
cat >> "${NEXUS_VMOPTIONS}" <<EOF

# Redirect Java user prefs away from non-existent home dir
-Djava.util.prefs.userRoot=${NEXUS_DATA}/jvm-prefs
EOF
mkdir -p "${NEXUS_DATA}/jvm-prefs"
echo "✓ JVM user prefs dir set to ${NEXUS_DATA}/jvm-prefs"

# Final ownership pass — covers nexus.properties + jvm-prefs
chown -R nexus:nexus "${NEXUS_DATA}"

echo ""
echo "✓ Nexus ${NEXUS_VERSION} installed successfully"
echo "  Home     : ${NEXUS_HOME}"
echo "  Data     : ${NEXUS_DATA}"
echo "  User     : nexus"
echo "  Arch     : ${NEXUS_ARCH}"
echo "  HTTP Port: ${NEXUS_PORT}"
echo "  Note     : Initial admin password will be at ${NEXUS_DATA}/nexus3/admin.password on first boot"
