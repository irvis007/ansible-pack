#!/usr/bin/env bash
# Cleanup Proxmox test VMs

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/lib/proxmox_functions.sh"

FORCE=false

# Parse arguments
if [[ "${1:-}" == "--force" ]]; then
    FORCE=true
fi

echo "========================================="
echo "Proxmox Test VM Cleanup"
echo "========================================="
echo

# Check if on Proxmox host
if ! is_proxmox_host; then
    log_error "Not running on Proxmox host"
    exit 1
fi

# Find test VMs (VMID 100-199)
TEST_VMS=$(qm list | awk '$1 >= 100 && $1 < 200 {print $1}')

if [ -z "$TEST_VMS" ]; then
    log_info "No test VMs found (VMID 100-199)"
    exit 0
fi

# Display VMs to be deleted
log_info "Found test VMs:"
qm list | awk '$1 >= 100 && $1 < 200 {print "  " $0}'
echo

# Confirm unless --force
if [ "$FORCE" = false ]; then
    read -p "Delete these VMs? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cleanup cancelled"
        exit 0
    fi
fi

# Delete VMs
DELETED_COUNT=0
for vmid in $TEST_VMS; do
    log_info "Deleting VM $vmid..."

    # Stop VM
    if [ "$(get_vm_status $vmid)" == "running" ]; then
        qm stop "$vmid" --skiplock || true
        sleep 2
    fi

    # Destroy VM
    if qm destroy "$vmid" --skiplock --purge; then
        log_success "VM $vmid deleted"
        ((DELETED_COUNT++))
    else
        log_error "Failed to delete VM $vmid"
    fi
done

echo
echo "========================================="
log_success "Cleanup complete: $DELETED_COUNT VMs deleted"
echo "========================================="
echo

# Show remaining VMs
log_info "Remaining VMs:"
qm list | awk '$1 >= 100 && $1 < 200 {print "  " $0}'
if [ -z "$(qm list | awk '$1 >= 100 && $1 < 200')" ]; then
    echo "  (none)"
fi
