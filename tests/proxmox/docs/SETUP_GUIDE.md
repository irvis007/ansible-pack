# Proxmox Testing Setup Guide

This guide walks you through setting up your Proxmox VE server for Layer 3 acceptance testing.

## Prerequisites

- Proxmox VE 7.x or 8.x installed and accessible
- Network connectivity to Proxmox host
- Sufficient resources: 4GB RAM + 40GB disk space for test VMs
- Command-line access to Proxmox host (for initial setup)

---

## Step 1: Create Proxmox API Token

API tokens allow Ansible to manage VMs without using your password.

### On Proxmox Web UI:

1. Navigate to **Datacenter → Permissions → API Tokens**
2. Click **Add**
3. Configure token:
   - **User**: Select your user (e.g., `root@pam`)
   - **Token ID**: `ansible-test` (or your preferred name)
   - **Privilege Separation**: Uncheck (for testing)
   - **Expire**: Never (or set far future date)
4. Click **Add**
5. **IMPORTANT**: Copy the token secret immediately - it won't be shown again!

### Save Credentials:

```bash
# From ansible-pack root directory
# Create credentials file (not tracked by git)
cat > tests/proxmox/.proxmox_credentials << EOF
export PROXMOX_HOST="pve.local"  # Your Proxmox hostname or IP
export PROXMOX_NODE="pve"        # Your Proxmox node name
export PROXMOX_USER="root@pam"
export PROXMOX_TOKEN_ID="ansible-test"
export PROXMOX_TOKEN="<paste-your-token-here>"
EOF

# Protect the file
chmod 600 tests/proxmox/.proxmox_credentials

# Source it
source tests/proxmox/.proxmox_credentials
```

---

## Step 2: Verify Proxmox Connectivity

### Check API Access:

```bash
# Test with pvesh (from Proxmox host)
pvesh get /nodes

# Test with curl (from anywhere)
curl -k -H "Authorization: PVEAPIToken=${PROXMOX_USER}!${PROXMOX_TOKEN_ID}=${PROXMOX_TOKEN}" \
  https://${PROXMOX_HOST}:8006/api2/json/nodes
```

**Expected**: JSON response listing your Proxmox nodes

###  Detect Node Name:

```bash
pvesh get /nodes --output-format json | jq -r '.[0].node'
```

Update `PROXMOX_NODE` in `.proxmox_credentials` with this value.

---

## Step 3: Identify Network Bridge

List available network bridges:

```bash
# On Proxmox host
pvesh get /nodes/${PROXMOX_NODE}/network --output-format json | \
  jq -r '.[] | select(.type=="bridge") | .iface'
```

**Common values**: `vmbr0` (default), `vmbr1`, etc.

**Result**: Note the bridge name for inventory configuration (usually `vmbr0`)

---

## Step 4: Identify Storage Pool

List available storage pools:

```bash
pvesh get /storage --output-format json | jq -r '.[] | "\(.storage) (\(.type))"'
```

**Look for**:
- `local-lvm` (thin LVM) - **Recommended** for VMs
- `local` (directory) - For ISOs/templates only
- `local-zfs` (ZFS) - If you have ZFS

**Result**: Note the storage pool for inventory (usually `local-lvm`)

---

## Step 5: Prepare SSH Keys

Generate SSH keys for VM access:

```bash
# Generate key if you don't have one
if [ ! -f ~/.ssh/ansible_key ]; then
  ssh-keygen -t ed25519 -f ~/.ssh/ansible_key -N "" -C "ansible@test-vms"
  echo "SSH key created at ~/.ssh/ansible_key"
else
  echo "SSH key already exists"
fi

# Display public key (needed for cloud-init)
cat ~/.ssh/ansible_key.pub
```

**Result**: Public key will be injected into VMs via cloud-init

---

## Step 6: Install Ansible Collection

The community.general collection provides Proxmox modules:

```bash
ansible-galaxy collection install community.general
```

**Verify installation**:
```bash
ansible-galaxy collection list | grep community.general
```

**Expected**: `community.general` version 5.0.0 or higher

---

## Step 7: Download Cloud Images (Optional)

Pre-download cloud images to speed up template creation:

```bash
# Ubuntu 22.04
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img \
  -O /tmp/ubuntu-22.04-cloudimg.img

# Debian 12
wget https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2 \
  -O /tmp/debian-12-cloudimg.qcow2
```

**Note**: The template creation script will download these automatically if not present.

---

## Step 8: Verify Configuration

Run the Proxmox connectivity check:

```bash
# From ansible-pack root directory
source tests/proxmox/.proxmox_credentials
./tests/proxmox/scripts/check_proxmox.sh
```

**Expected output**:
```
✓ Proxmox API accessible
✓ Node found: pve
✓ Network bridge: vmbr0
✓ Storage pool: local-lvm
✓ SSH key exists: ~/.ssh/ansible_key.pub
✓ Ansible collection community.general: installed
```

---

## Configuration Summary

After completing this setup, you should have:

- ✅ Proxmox API token created and saved
- ✅ Network bridge identified (e.g., `vmbr0`)
- ✅ Storage pool identified (e.g., `local-lvm`)
- ✅ SSH keys generated (`~/.ssh/ansible_key`)
- ✅ Ansible collections installed (`community.general`)
- ✅ Credentials file created (`.proxmox_credentials`)

**Variables to use in inventory**:
- **proxmox_host**: Your Proxmox hostname/IP
- **proxmox_node**: Node name (from Step 2)
- **network_bridge**: Bridge name (from Step 3)
- **storage**: Storage pool (from Step 4)

---

## Next Steps

1. Create VM templates: `./tests/proxmox/scripts/create_templates.sh`
2. Configure inventory: Edit `tests/proxmox/inventory.yml`
3. Run tests: `./tests/proxmox/scripts/run_tests.sh workstation`

---

## Troubleshooting

### API Token Not Working

- **Check token format**: Should be `USER@REALM!TOKENID=SECRET`
- **Verify privileges**: Token needs VM.* permissions
- **Check expiration**: Token might have expired

### Network Bridge Not Found

```bash
# List all network interfaces
ip link show

# Check Proxmox network config
cat /etc/network/interfaces
```

### Storage Pool Issues

```bash
# Check storage configuration
pvesm status

# Verify LVM
lvs
vgs
```

### SSH Key Problems

```bash
# Check key permissions
ls -la ~/.ssh/ansible_key*

# Should be:
# -rw------- ansible_key (private)
# -rw-r--r-- ansible_key.pub (public)
```

---

## Security Notes

- **API Token**: Keep `.proxmox_credentials` secure, never commit to git
- **SSH Keys**: Use separate keys for testing, not your personal keys
- **Test VMs**: Use isolated network or VLAN for test VMs if possible
- **Cleanup**: Always clean up test VMs after use to free resources

---

## Additional Resources

- [Proxmox API Documentation](https://pve.proxmox.com/pve-docs/api-viewer/)
- [community.general.proxmox_kvm](https://docs.ansible.com/ansible/latest/collections/community/general/proxmox_kvm_module.html)
- [Cloud-Init Documentation](https://cloudinit.readthedocs.io/)
