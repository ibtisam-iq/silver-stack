#!/bin/bash
set -euo pipefail

#######################################################################
# Jenkins Installation Script
#
# Installs Java 21 and Jenkins LTS on Ubuntu.
#
# Arguments:
#   PORT - Jenkins HTTP port (default: 8080)
#
# Author: Muhammad Ibtisam Iqbal
#######################################################################

JENKINS_PORT=${1:-8080}

if ! [[ "${JENKINS_PORT}" =~ ^[0-9]+$ ]] || \
   [ "${JENKINS_PORT}" -lt 1 ] || \
   [ "${JENKINS_PORT}" -gt 65535 ]; then
    echo "ERROR: Invalid port: ${JENKINS_PORT}"
    echo "Port must be a number between 1 and 65535"
    exit 1
fi

echo "Installing Java 21..."
apt-get update
apt-get install -y --no-install-recommends openjdk-21-jdk
java -version

echo "Adding Jenkins GPG key..."
wget -q -O /usr/share/keyrings/jenkins-keyring.asc \
    https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

echo "Adding Jenkins repository..."
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
    > /etc/apt/sources.list.d/jenkins.list

echo "Updating package index..."
apt-get update

echo "Installing Jenkins..."
apt-get install -y --no-install-recommends jenkins

echo "Setting up Jenkins directories..."
mkdir -p /var/lib/jenkins
chown -R jenkins:jenkins /var/lib/jenkins
chmod -R 755 /var/lib/jenkins

mkdir -p /var/lib/jenkins/plugins
chown -R jenkins:jenkins /var/lib/jenkins/plugins

mkdir -p /var/lib/jenkins/workspace
chown -R jenkins:jenkins /var/lib/jenkins/workspace

mkdir -p /var/lib/jenkins/.ssh
chown jenkins:jenkins /var/lib/jenkins/.ssh
chmod 700 /var/lib/jenkins/.ssh

mkdir -p /var/log/jenkins
chown -R jenkins:jenkins /var/log/jenkins

echo "Verifying Jenkins user..."
id jenkins

echo ""
echo "✓ Jenkins installed successfully"
echo "  Version : $(dpkg -l | grep jenkins | awk '{print $3}')"
echo "  Home    : /var/lib/jenkins"
echo "  User    : jenkins"
echo "  Group   : jenkins"
echo "  HTTP Port: ${JENKINS_PORT}"
