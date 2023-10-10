#!/bin/bash
# Check Proxmox environment and prerequisites

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/proxmox_functions.sh"

# Source credentials if available
if [ -f "$SCRIPT_DIR/../.proxmox_credentials" ]; then
    source "$SCRIPT_DIR/../.proxmox_credentials"
fi

echo "========================================="
echo "Proxmox Environment Check"
echo "========================================="
echo

# Check if on Proxmox host
if ! is_proxmox_host; then
    log_error "Not running on Proxmox host (qm command not found)"
    echo "This script must run on the Proxmox host"
    exit 1
fi
log_success "Running on Proxmox host"

# Check API access
if check_proxmox_connection; then
    log_success "Proxmox API accessible"
else
    log_error "Cannot access Proxmox API"
    exit 1
fi

# Detect node
echo
log_info "Detecting Proxmox node..."
NODE=$(pvesh get /nodes --output-format json | jq -r '.[0].node' 2>/dev/null)
if [ -n "$NODE" ]; then
    log_success "Node found: $NODE"
    echo "  Update your .proxmox_credentials: export PROXMOX_NODE=\"$NODE\""
else
    log_error "Could not detect node"
fi

# List network bridges
echo
log_info "Network bridges:"
pvesh get /nodes/${NODE}/network --output-format json 2>/dev/null | \
    jq -r '.[] | select(.type=="bridge") | "  " + .iface' || echo "  Could not detect bridges"

# List storage pools
echo
log_info "Storage pools:"
pvesh get /storage --output-format json 2>/dev/null | \
    jq -r '.[] | "  " + .storage + " (" + .type + ")"' || echo "  Could not detect storage"

# Check templates
echo
log_info "VM Templates:"
qm list | awk '$3 ~ /template/ {print "  " $1 " - " $2}'
TEMPLATE_COUNT=$(qm list | awk '$3 ~ /template/ {count++} END {print count+0}')
if [ "$TEMPLATE_COUNT" -eq 0 ]; then
    log_warning "No templates found"
    echo "  Run: ./scripts/create_templates.sh"
fi

# Check SSH key
echo
SSH_KEY="$HOME/.ssh/ansible_key.pub"
if [ -f "$SSH_KEY" ]; then
    log_success "SSH key exists: $SSH_KEY"
else
    log_warning "SSH key not found: $SSH_KEY"
    echo "  Run: ssh-keygen -t ed25519 -f ~/.ssh/ansible_key -N ''"
fi

# Check Ansible collection
echo
if ansible-galaxy collection list 2>/dev/null | grep -q community.general; then
    log_success "Ansible collection community.general: installed"
else
    log_warning "Ansible collection community.general: not installed"
    echo "  Run: ansible-galaxy collection install community.general"
fi

# List test VMs
echo
log_info "Current test VMs (VMID 100-199):"
TEST_VMS=$(qm list | awk '$1 >= 100 && $1 < 200')
if [ -z "$TEST_VMS" ]; then
    echo "  No test VMs found"
else
    echo "$TEST_VMS" | awk '{print "  " $0}'
fi

echo
echo "========================================="
echo "Environment check complete!"
echo "========================================="
