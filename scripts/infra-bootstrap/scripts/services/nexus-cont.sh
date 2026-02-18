#!/bin/bash

# infra-bootstrap - Nexus Container Setup Script
# -------------------------------------------------
# This script installs and runs Nexus container on Linux.

set -e  # Exit immediately if a command fails
set -o pipefail  # Ensure failures in piped commands are detected

# Handle script failures
trap 'echo -e "\n\033[1;31m❌ Error occurred at line $LINENO. Exiting...\033[0m\n" && exit 1' ERR

REPO_URL="https://raw.githubusercontent.com/ibtisam-iq/infra-bootstrap/main"

# ==================================================
# 🛠️ Preflight Check
# ==================================================
echo -e "\n\033[1;34m🚀 Running preflight.sh script to ensure system meets requirements for deploying Nexus container...\033[0m\n"
bash <(curl -sL "$REPO_URL/preflight.sh") || { echo -e "\n\033[1;31m❌ Failed to execute preflight.sh. Exiting...\033[0m"; exit 1; }
echo -e "\n\033[1;32m✅ System meets the requirements for deploying Nexus container.\033[0m"

# 🛑 Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "\n❌ Docker is NOT installed."
    echo -e "\n🚀 Installing Docker..."
    sudo apt-get update -qq
    sudo apt-get install -yq docker.io
    sudo usermod -aG docker $USER
    sudo systemctl enable docker --now
    sudo systemctl start docker
    echo -e "\n✅ Docker installed successfully to deploy Nexus container!\n"
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

# Prompt user for port (default: 8081)
while true; do
    read -rp "🔹 Please enter the port for Nexus container (Press Enter for default: 8081): " USER_PORT < /dev/tty
    USER_PORT=${USER_PORT:-8081}  # Default to 8081 if empty
    if validate_port "$USER_PORT"; then
        break
    fi
done

echo -e "\n✅ Using port: $USER_PORT"

# Remove old container if exists

if sudo docker inspect nexus &>/dev/null; then
    echo "✅ Removing existing Nexus container..."
    sudo docker rm -f nexus
fi

# Run Nexus container
echo -e "\n🚀 Deploying Nexus on port $USER_PORT..."
sudo docker run -d --name nexus \
  -p ${USER_PORT}:8081 \
  --restart always \
  sonatype/nexus3

# Check container status
echo -e "\n🔍 Checking Nexus status..."
if sudo docker ps --filter "name=nexus" --filter "status=running" | grep nexus; then
    echo -e "\n✅ Nexus is running on port $USER_PORT!" 
else
    echo -e "\n❌ Nexus failed to start. Restarting..."
    sudo docker restart nexus
fi

# Get the local machine's primary IP
LOCAL_IP=$(hostname -I | awk '{print $1}')

# Get the public IP (if accessible)
PUBLIC_IP=$(curl -s ifconfig.me || echo "Not Available")

# Print both access URLs and let the user decide
echo -e "\n🔗 Access Nexus using one of the following based on your network:"
echo -e "\n - Local Network:  http://$LOCAL_IP:$USER_PORT"
echo -e "\n - Public Network: http://$PUBLIC_IP:$USER_PORT\n"


# Display Nexus Access URL

echo -e "\n🔑 Please put the password to unlock Nexus: $(sudo docker exec nexus cat /nexus-data/admin.password)\n"
echo -e "\n📌 Note: It may take a few minutes for Nexus container to start completely.\n"

# ==================================================
# 🎉 Setup Complete! Thank You! 🙌
# ==================================================
echo -e "\n\033[1;33m✨  Thank you for choosing infra-bootstrap - Muhammad Ibtisam 🚀\033[0m\n"
echo -e "\033[1;32m💡 Automation is not about replacing humans; it's about freeing them to be more human—to create, innovate, and lead. \033[0m\n"