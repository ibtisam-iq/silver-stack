#!/bin/bash

# silver-stack - Sonarqube Container Setup Script
# -------------------------------------------------
# This script installs and runs SonarQube container on Linux.

set -e  # Exit immediately if a command fails
set -o pipefail  # Ensure failures in piped commands are detected

# Handle script failures
trap 'echo -e "\n\033[1;31m❌ Error occurred at line $LINENO. Exiting...\033[0m\n" && exit 1' ERR

REPO_URL="https://raw.githubusercontent.com/ibtisam-iq/silver-stack/main"

# ==================================================
# 🛠️ Preflight Check
# ==================================================
echo -e "\n\033[1;34m🚀 Running preflight.sh script to ensure system meets requirements for deploying SonarQube container...\033[0m\n"
bash <(curl -sL "$REPO_URL/preflight.sh") || { echo -e "\n\033[1;31m❌ Failed to execute preflight.sh. Exiting...\033[0m"; exit 1; }
echo -e "\n\033[1;32m✅ System meets the requirements for deploying SonarQube container.\033[0m"

# 🛑 Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "\n❌ Docker is NOT installed."
    echo -e "\n🚀 Installing Docker..."
    sudo apt-get update -qq
    sudo apt-get install -yq docker.io
    sudo usermod -aG docker $USER
    sudo systemctl enable docker --now
    sudo systemctl start docker
    echo -e "\n✅ Docker installed successfully to deploy Sonarqube container!"
fi

# ✅ Ensure Docker is running
if ! systemctl is-active --quiet docker; then
    echo -e "\n🔄 Starting Docker..."
    sudo systemctl start docker
    echo -e "\n✅ Docker is now running!"
fi

# Function to validate port
validate_port() {
    local port=$1
    if [[ ! $port =~ ^[0-9]+$ ]] || ((port < 1024 || port > 65535)); then
        echo -e "\n❌ Invalid port! Please enter a number between 1024 and 65535."
        return 1
    fi
    return 0
}

# Prompt user for port (default: 9000)
while true; do
    read -rp "✅ Please enter the port for SonarQube container (Press Enter for default: 9000): " USER_PORT < /dev/tty
    USER_PORT=${USER_PORT:-9000}  # Default to 9000 if empty
    if validate_port "$USER_PORT"; then
        break
    fi
done

echo -e "\n✅ Using port: $USER_PORT"

# Remove old container if exists

if sudo docker inspect sonarqube &>/dev/null; then
    echo "✅ Removing existing SonarQube container..."
    sudo docker rm -f sonarqube
fi

# Run SonarQube container
echo -e "\n🚀 Deploying SonarQube on port $USER_PORT..."
sudo docker run -d --name sonarqube \
  -p ${USER_PORT}:9000 \
  -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
  --restart always \
  sonarqube:lts-community

# Check container status
echo -e "\n🔍 Checking SonarQube status..."
if sudo docker ps --filter "name=sonarqube" --filter "status=running" | grep sonarqube; then
    echo -e "\n✅ SonarQube is running on port $USER_PORT!" 
else
    echo -e "\n❌ SonarQube failed to start. Restarting..."
    sudo docker restart sonarqube
fi

# Get the local machine's primary IP
LOCAL_IP=$(hostname -I | awk '{print $1}')

# Get the public IP (if accessible)
PUBLIC_IP=$(curl -s ifconfig.me || echo "Not Available")

# Print both access URLs and let the user decide
echo -e "\n🔗 Access SonarQube using one of the following based on your network:"
echo -e "\n - Local Network:  http://$LOCAL_IP:$USER_PORT"
echo -e "\n - Public Network: http://$PUBLIC_IP:$USER_PORT\n"


# Display SonarQube Access URL
echo -e "\n🔑 Default credentials: admin/admin\n"
echo -e "\n📌 Note: It may take a few minutes for SonarQube container to start completely.\n"

# ==================================================
# 🎉 Setup Complete! Thank You! 🙌
# ==================================================
echo -e "\n\033[1;33m✨  Thank you for choosing silver-stack - Muhammad Ibtisam 🚀\033[0m\n"
echo -e "\033[1;32m💡 Automation is not about replacing humans; it's about freeing them to be more human—to create, innovate, and lead. \033[0m\n"