#!/usr/bin/env bash
# Setup LXD container for integration testing

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
CONTAINER_NAME="${1:-test-workstation-ubuntu}"
IMAGE="${2:-ubuntu:22.04}"
PROFILE="default"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}LXD Container Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo "Container: $CONTAINER_NAME"
echo "Image: $IMAGE"
echo ""

# Check if LXD is installed
if ! command -v lxc &> /dev/null; then
    echo -e "${RED}ERROR: LXD is not installed${NC}"
    echo "Install with: sudo snap install lxd"
    exit 1
fi

# Check if container already exists
if lxc info "$CONTAINER_NAME" &> /dev/null; then
    echo -e "${YELLOW}Container $CONTAINER_NAME already exists${NC}"
    read -p "Delete and recreate? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Stopping and deleting existing container..."
        lxc stop "$CONTAINER_NAME" --force 2>/dev/null || true
        lxc delete "$CONTAINER_NAME" --force
    else
        echo "Using existing container"
        exit 0
    fi
fi

# Launch container
echo -e "${GREEN}Launching container...${NC}"
lxc launch "$IMAGE" "$CONTAINER_NAME"

# Wait for container to be ready
echo "Waiting for container to be ready..."
sleep 5

# Wait for cloud-init to finish
echo "Waiting for cloud-init..."
lxc exec "$CONTAINER_NAME" -- sh -c 'command -v cloud-init && cloud-init status --wait || echo "cloud-init not available"'

# Update package cache
echo "Updating package cache..."
if [[ "$IMAGE" == ubuntu:* ]] || [[ "$IMAGE" == debian:* ]]; then
    lxc exec "$CONTAINER_NAME" -- apt-get update
fi

# Install Python (required for Ansible)
echo "Installing Python..."
if [[ "$IMAGE" == ubuntu:* ]] || [[ "$IMAGE" == debian:* ]]; then
    lxc exec "$CONTAINER_NAME" -- apt-get install -y python3 python3-apt sudo
fi

# Configure sudo without password for testing
echo "Configuring sudo..."
lxc exec "$CONTAINER_NAME" -- sh -c "echo 'root ALL=(ALL:ALL) NOPASSWD:ALL' > /etc/sudoers.d/testing"
lxc exec "$CONTAINER_NAME" -- chmod 0440 /etc/sudoers.d/testing

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Container ready!${NC}"
echo -e "${GREEN}========================================${NC}"
echo "Name: $CONTAINER_NAME"
echo "IP: $(lxc list "$CONTAINER_NAME" -c 4 --format csv | cut -d' ' -f1)"
echo ""
echo "Access with:"
echo "  lxc exec $CONTAINER_NAME -- bash"
echo ""
echo "Test with Ansible:"
echo "  ansible -i tests/lxd/inventory.yml $CONTAINER_NAME -m ping"
echo ""
