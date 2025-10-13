#!/bin/bash

# Banking K8s Infrastructure - Environment Setup for Minikube
# This script sets up the complete development environment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🏦 Banking K8s Infrastructure - Environment Setup${NC}"
echo "=================================================="

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}This script is optimized for macOS${NC}"
    exit 1
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install via Homebrew
install_with_brew() {
    local package=$1
    local cask=${2:-false}
    
    if [ "$cask" = true ]; then
        echo -e "${YELLOW}Installing $package via Homebrew Cask...${NC}"
        brew install --cask "$package"
    else
        echo -e "${YELLOW}Installing $package via Homebrew...${NC}"
        brew install "$package"
    fi
}

# Check and install Homebrew
if ! command_exists brew; then
    echo -e "${YELLOW}Installing Homebrew...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo -e "${GREEN}✓ Homebrew already installed${NC}"
fi

# Update Homebrew
echo -e "${YELLOW}Updating Homebrew...${NC}"
brew update

# Install required tools
tools=(
    "docker"
    "kubectl"
    "minikube"
    "helm"
    "python3"
    "node"
)

cask_tools=(
    "docker"
)

echo -e "${BLUE}Installing required tools...${NC}"

for tool in "${tools[@]}"; do
    if ! command_exists "$tool"; then
        if [[ " ${cask_tools[@]} " =~ " ${tool} " ]]; then
            install_with_brew "$tool" true
        else
            install_with_brew "$tool"
        fi
    else
        echo -e "${GREEN}✓ $tool already installed${NC}"
    fi
done

# Start Docker Desktop (if not running)
echo -e "${BLUE}Checking Docker Desktop...${NC}"
if ! docker info >/dev/null 2>&1; then
    echo -e "${YELLOW}Starting Docker Desktop...${NC}"
    open -a Docker
    echo -e "${YELLOW}Waiting for Docker to start...${NC}"
    while ! docker info >/dev/null 2>&1; do
        sleep 5
    done
fi
echo -e "${GREEN}✓ Docker is running${NC}"

# Configure Minikube
echo -e "${BLUE}Configuring Minikube...${NC}"
minikube config set driver docker
minikube config set memory 4096
minikube config set cpus 2

# Start Minikube if not running
if ! minikube status >/dev/null 2>&1; then
    echo -e "${YELLOW}Starting Minikube...${NC}"
    minikube start --driver=docker --memory=4096 --cpus=2
else
    echo -e "${GREEN}✓ Minikube already running${NC}"
fi

# Enable required addons
echo -e "${BLUE}Enabling Minikube addons...${NC}"
minikube addons enable ingress
minikube addons enable dashboard
minikube addons enable metrics-server

# Install Python dependencies
echo -e "${BLUE}Setting up Python environment...${NC}"
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi
source venv/bin/activate
pip install --upgrade pip
pip install fastapi uvicorn asyncpg redis boto3 pyjwt python-multipart

# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}Creating .env file...${NC}"
    cp .env.example .env
fi

# Set kubectl context to minikube
kubectl config use-context minikube

echo -e "${GREEN}🎉 Environment setup completed successfully!${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Run: ${YELLOW}make deploy-all${NC}"
echo "2. Access the application: ${YELLOW}minikube service banking-frontend${NC}"
echo "3. View dashboard: ${YELLOW}minikube dashboard${NC}"