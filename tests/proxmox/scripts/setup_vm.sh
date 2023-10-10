#!/bin/bash
# Create and configure Proxmox VM for testing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/proxmox_functions.sh"

# Source credentials
if [ -f "$SCRIPT_DIR/../.proxmox_credentials" ]; then
    source "$SCRIPT_DIR/../.proxmox_credentials"
fi

# Configuration
NODE="${PROXMOX_NODE:-pve}"
STORAGE="${STORAGE:-local-lvm}"
BRIDGE="${BRIDGE:-vmbr0}"

# Usage
if [ $# -lt 3 ]; then
    echo "Usage: $0 <vm_name> <vmid> <template_id> [cores] [memory]"
    echo
    echo "Example:"
    echo "  $0 test-workstation-ubuntu 100 9000"
    echo "  $0 test-server-ubuntu 101 9000 1 2048"
    exit 1
fi

VM_NAME=$1
VMID=$2
TEMPLATE_ID=$3
CORES=${4:-1}
MEMORY=${5:-2048}

echo "========================================="
echo "Creating VM: $VM_NAME"
echo "========================================="
echo "VM ID: $VMID"
echo "Template: $TEMPLATE_ID"
echo "Cores: $CORES"
echo "Memory: ${MEMORY}MB"
echo "========================================="
echo

# Check if VM already exists
if vm_exists "$VMID"; then
    log_warning "VM $VMID already exists"
    read -p "Destroy and recreate? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Stopping VM..."
        qm stop "$VMID" || true
        sleep 2
        log_info "Destroying VM..."
        qm destroy "$VMID"
        log_success "VM destroyed"
    else
        exit 0
    fi
fi

# Clone template
log_info "Cloning template $TEMPLATE_ID to VM $VMID..."
qm clone "$TEMPLATE_ID" "$VMID" --name "$VM_NAME" --full
log_success "VM cloned"

# Configure resources
log_info "Configuring resources..."
qm set "$VMID" --cores "$CORES" --memory "$MEMORY"
log_success "Resources configured"

# Start VM
log_info "Starting VM..."
qm start "$VMID"
wait_for_vm_status "$VMID" "running" 60
log_success "VM started"

# Get IP address
log_info "Getting IP address (this may take 30-60 seconds)..."
VM_IP=$(get_vm_ip "$VMID" 120)
if [ -z "$VM_IP" ]; then
    log_error "Could not get VM IP address"
    log_info "You can check manually: qm guest cmd $VMID network-get-interfaces"
    exit 1
fi
log_success "VM IP: $VM_IP"

# Wait for SSH
wait_for_ssh "$VM_IP" "ansible" "$HOME/.ssh/ansible_key" 120
if [ $? -ne 0 ]; then
    log_error "SSH not available"
    exit 1
fi

# Wait for cloud-init
wait_for_cloud_init "$VM_IP" "ansible" "$HOME/.ssh/ansible_key" 180
if [ $? -ne 0 ]; then
    log_warning "Cloud-init may not have completed successfully"
fi

# Display info
show_vm_info "$VMID" "$VM_NAME" "$VM_IP"

# Export IP for inventory
echo
log_info "To use this VM in tests, export:"
echo "  export ${VM_NAME//-/_}_IP=\"$VM_IP\""
echo

log_success "VM $VM_NAME ready!"
