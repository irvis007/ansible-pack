#!/bin/bash
# Create VM templates for Proxmox testing
# This script creates cloud-init enabled VM templates for Ubuntu 22.04 and Debian 12

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Source credentials if available
if [ -f "$SCRIPT_DIR/../.proxmox_credentials" ]; then
    source "$SCRIPT_DIR/../.proxmox_credentials"
else
    echo -e "${YELLOW}Warning: .proxmox_credentials not found${NC}"
    echo "Using default values. Edit script or create credentials file."
fi

# Configuration
PROXMOX_NODE="${PROXMOX_NODE:-pve}"
STORAGE="${STORAGE:-local-lvm}"
BRIDGE="${BRIDGE:-vmbr0}"
UBUNTU_TEMPLATE_ID="${UBUNTU_TEMPLATE_ID:-9000}"
DEBIAN_TEMPLATE_ID="${DEBIAN_TEMPLATE_ID:-9001}"

# Image URLs
UBUNTU_IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
DEBIAN_IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"

# Temporary directory
TMP_DIR="/tmp/proxmox-templates"

echo "========================================="
echo "Proxmox VM Template Creation"
echo "========================================="
echo "Node: $PROXMOX_NODE"
echo "Storage: $STORAGE"
echo "Bridge: $BRIDGE"
echo "Ubuntu Template ID: $UBUNTU_TEMPLATE_ID"
echo "Debian Template ID: $DEBIAN_TEMPLATE_ID"
echo "========================================="
echo

# Check if running on Proxmox host
if ! command -v qm &> /dev/null; then
    echo -e "${RED}Error: This script must run on the Proxmox host${NC}"
    echo "The 'qm' command is not available"
    echo
    echo "To run from remote machine, SSH into Proxmox first:"
    echo "  ssh root@\$PROXMOX_HOST 'bash -s' < $0"
    exit 1
fi

# Check SSH key
# First try: Use key from /tmp (copied from local machine)
# Second try: Use key from $HOME (if running locally)
# Third try: Generate new key

if [ -f "/tmp/ansible_key.pub" ]; then
    SSH_KEY="/tmp/ansible_key.pub"
    echo -e "${GREEN}✓${NC} Using SSH key from: /tmp/ansible_key.pub (copied from local machine)"
elif [ -f "$HOME/.ssh/ansible_key.pub" ]; then
    SSH_KEY="$HOME/.ssh/ansible_key.pub"
    echo -e "${YELLOW}⚠${NC} Using SSH key from: $HOME/.ssh/ansible_key.pub"
    echo "    Note: This should match your local machine's key for Ansible to work"
else
    echo -e "${YELLOW}Warning: No SSH public key found${NC}"
    echo "Expected locations:"
    echo "  - /tmp/ansible_key.pub (copied from local machine)"
    echo "  - $HOME/.ssh/ansible_key.pub"
    echo ""
    echo "To copy key from local machine:"
    echo "  scp ~/.ssh/ansible_key.pub root@\$PROXMOX_HOST:/tmp/"
    echo ""
    read -p "Generate new SSH key on this host? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ssh-keygen -t ed25519 -f "$HOME/.ssh/ansible_key" -N "" -C "ansible@test-vms"
        SSH_KEY="$HOME/.ssh/ansible_key.pub"
    else
        echo "Aborting. Please provide SSH public key."
        exit 1
    fi
fi

SSH_KEY_CONTENT=$(cat "$SSH_KEY")
echo -e "${GREEN}✓${NC} SSH key found: $SSH_KEY"
echo

# Create temporary directory
mkdir -p "$TMP_DIR"

#######################################
# Function: create_template
# Arguments:
#   $1 - Template ID
#   $2 - Template Name
#   $3 - Image URL
#   $4 - OS Type (ubuntu|debian)
#######################################
create_template() {
    local TEMPLATE_ID=$1
    local TEMPLATE_NAME=$2
    local IMAGE_URL=$3
    local OS_TYPE=$4
    local IMAGE_FILE="$TMP_DIR/${TEMPLATE_NAME}.img"

    echo "========================================="
    echo "Creating template: $TEMPLATE_NAME (ID: $TEMPLATE_ID)"
    echo "========================================="

    # Check if template already exists
    if qm status "$TEMPLATE_ID" &>/dev/null; then
        echo -e "${YELLOW}Template $TEMPLATE_ID already exists${NC}"
        read -p "Do you want to recreate it? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Skipping $TEMPLATE_NAME"
            return 0
        fi
        echo "Destroying existing template..."
        qm destroy "$TEMPLATE_ID"
    fi

    # Download cloud image
    echo "Downloading cloud image..."
    if [ ! -f "$IMAGE_FILE" ]; then
        wget -O "$IMAGE_FILE" "$IMAGE_URL"
    else
        echo "Image already downloaded, using cache"
    fi
    echo -e "${GREEN}✓${NC} Image downloaded"

    # Create VM
    echo "Creating VM $TEMPLATE_ID..."
    qm create "$TEMPLATE_ID" \
        --name "$TEMPLATE_NAME" \
        --memory 2048 \
        --cores 2 \
        --net0 virtio,bridge="$BRIDGE" \
        --scsihw virtio-scsi-pci \
        --ostype l26
    echo -e "${GREEN}✓${NC} VM created"

    # Import disk
    echo "Importing disk..."
    qm importdisk "$TEMPLATE_ID" "$IMAGE_FILE" "$STORAGE"
    echo -e "${GREEN}✓${NC} Disk imported"

    # Attach disk
    echo "Attaching disk..."
    qm set "$TEMPLATE_ID" --scsi0 "${STORAGE}:vm-${TEMPLATE_ID}-disk-0"
    echo -e "${GREEN}✓${NC} Disk attached"

    # Configure boot
    echo "Configuring boot..."
    qm set "$TEMPLATE_ID" --boot c --bootdisk scsi0
    echo -e "${GREEN}✓${NC} Boot configured"

    # Add cloud-init drive
    echo "Adding cloud-init drive..."
    qm set "$TEMPLATE_ID" --ide2 "${STORAGE}:cloudinit"
    echo -e "${GREEN}✓${NC} Cloud-init drive added"

    # Configure cloud-init
    echo "Configuring cloud-init..."
    qm set "$TEMPLATE_ID" \
        --ciuser ansible \
        --cipassword "$(openssl rand -base64 32)" \
        --sshkeys <(echo "$SSH_KEY_CONTENT") \
        --ipconfig0 ip=dhcp
    echo -e "${GREEN}✓${NC} Cloud-init configured"

    # Enable QEMU guest agent
    echo "Enabling QEMU guest agent..."
    qm set "$TEMPLATE_ID" --agent enabled=1
    echo -e "${GREEN}✓${NC} Guest agent enabled"

    # Set serial console
    echo "Setting serial console..."
    qm set "$TEMPLATE_ID" --serial0 socket --vga serial0
    echo -e "${GREEN}✓${NC} Serial console configured"

    # Resize disk to 20GB
    echo "Resizing disk to 20GB..."
    qm resize "$TEMPLATE_ID" scsi0 20G
    echo -e "${GREEN}✓${NC} Disk resized"

    # Convert to template
    echo "Converting to template..."
    qm template "$TEMPLATE_ID"
    echo -e "${GREEN}✓${NC} Converted to template"

    echo -e "${GREEN}✓✓✓ Template $TEMPLATE_NAME created successfully!${NC}"
    echo
}

#######################################
# Main execution
#######################################

# Create Ubuntu template
create_template \
    "$UBUNTU_TEMPLATE_ID" \
    "ubuntu-22.04-template" \
    "$UBUNTU_IMAGE_URL" \
    "ubuntu"

# Create Debian template
create_template \
    "$DEBIAN_TEMPLATE_ID" \
    "debian-12-template" \
    "$DEBIAN_IMAGE_URL" \
    "debian"

# Cleanup
echo "Cleaning up temporary files..."
rm -rf "$TMP_DIR"
echo -e "${GREEN}✓${NC} Cleanup complete"

echo
echo "========================================="
echo "Template creation complete!"
echo "========================================="
echo "Templates created:"
echo "  - $UBUNTU_TEMPLATE_ID: ubuntu-22.04-template"
echo "  - $DEBIAN_TEMPLATE_ID: debian-12-template"
echo
echo "Verify templates:"
echo "  pvesh get /cluster/resources --type vm | grep template"
echo
echo "Next steps:"
echo "  1. Configure inventory: tests/proxmox/inventory.yml"
echo "  2. Run tests: ./tests/proxmox/scripts/run_tests.sh"
echo "========================================="
