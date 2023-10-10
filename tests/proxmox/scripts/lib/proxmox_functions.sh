#!/bin/bash
# Shared functions for Proxmox VM management scripts

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if running on Proxmox host
is_proxmox_host() {
    command -v qm &> /dev/null
}

# Verify Proxmox API connectivity
check_proxmox_connection() {
    if ! is_proxmox_host; then
        log_error "Not running on Proxmox host"
        return 1
    fi

    if ! qm list &> /dev/null; then
        log_error "Cannot access Proxmox API"
        return 1
    fi

    return 0
}

# Check if VM exists
vm_exists() {
    local vmid=$1
    qm status "$vmid" &>/dev/null
}

# Get VM status
get_vm_status() {
    local vmid=$1
    qm status "$vmid" 2>/dev/null | awk '{print $2}'
}

# Wait for VM to reach status
wait_for_vm_status() {
    local vmid=$1
    local desired_status=$2
    local timeout=${3:-60}
    local elapsed=0

    log_info "Waiting for VM $vmid to reach status: $desired_status"

    while [ $elapsed -lt $timeout ]; do
        local current_status=$(get_vm_status "$vmid")
        if [ "$current_status" == "$desired_status" ]; then
            log_success "VM $vmid is $desired_status"
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done

    log_error "Timeout waiting for VM $vmid to reach $desired_status"
    return 1
}

# Get VM IP address
get_vm_ip() {
    local vmid=$1
    local timeout=${2:-120}
    local elapsed=0

    log_info "Waiting for VM $vmid to get IP address..."

    while [ $elapsed -lt $timeout ]; do
        # Try to get IP from QEMU guest agent
        local ip=$(qm guest cmd "$vmid" network-get-interfaces 2>/dev/null | \
                   jq -r '.[] | select(.name=="eth0" or .name=="ens18") |
                   ."ip-addresses"[]? | select(."ip-address-type"=="ipv4") |
                   ."ip-address"' 2>/dev/null | head -n1)

        if [ -n "$ip" ] && [ "$ip" != "127.0.0.1" ]; then
            echo "$ip"
            return 0
        fi

        sleep 3
        elapsed=$((elapsed + 3))
    done

    log_error "Timeout waiting for VM $vmid IP address"
    return 1
}

# Test SSH connectivity
test_ssh() {
    local ip=$1
    local user=${2:-ansible}
    local key=${3:-$HOME/.ssh/ansible_key}
    local timeout=${4:-30}

    log_info "Testing SSH connectivity to $user@$ip..."

    ssh -i "$key" \
        -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o BatchMode=yes \
        "$user@$ip" "echo SSH_OK" &>/dev/null

    return $?
}

# Wait for SSH
wait_for_ssh() {
    local ip=$1
    local user=${2:-ansible}
    local key=${3:-$HOME/.ssh/ansible_key}
    local timeout=${4:-120}
    local elapsed=0

    log_info "Waiting for SSH on $ip..."

    while [ $elapsed -lt $timeout ]; do
        if test_ssh "$ip" "$user" "$key"; then
            log_success "SSH is ready on $ip"
            return 0
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done

    log_error "Timeout waiting for SSH on $ip"
    return 1
}

# Wait for cloud-init completion
wait_for_cloud_init() {
    local ip=$1
    local user=${2:-ansible}
    local key=${3:-$HOME/.ssh/ansible_key}
    local timeout=${4:-300}

    log_info "Waiting for cloud-init to complete on $ip..."

    ssh -i "$key" \
        -o ConnectTimeout=10 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        "$user@$ip" \
        "cloud-init status --wait --long" &>/dev/null

    if [ $? -eq 0 ]; then
        log_success "Cloud-init completed"
        return 0
    else
        log_error "Cloud-init failed or timed out"
        return 1
    fi
}

# List test VMs
list_test_vms() {
    log_info "Test VMs (VMID 100-199):"
    qm list | awk '$1 >= 100 && $1 < 200 {print}'
}

# Display VM info
show_vm_info() {
    local vmid=$1
    local name=$2
    local ip=$3

    echo "========================================="
    echo "VM Information"
    echo "========================================="
    echo "VM ID: $vmid"
    echo "Name: $name"
    echo "IP Address: $ip"
    echo "Status: $(get_vm_status $vmid)"
    echo
    echo "Access VM:"
    echo "  ssh -i ~/.ssh/ansible_key ansible@$ip"
    echo
    echo "Console access:"
    echo "  qm terminal $vmid"
    echo "========================================="
}
