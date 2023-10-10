# Proxmox Layer 3 Testing Checklist

This checklist guides you through testing the Proxmox infrastructure locally before finalizing documentation.

## Prerequisites

- [ ] Proxmox VE accessible on local network
- [ ] SSH access to Proxmox host
- [ ] ~4GB RAM + 40GB disk free on Proxmox

## 🔑 SSH Key Workflow (Read This First!)

**Critical understanding:**

```
┌─────────────────┐         ┌──────────────────┐         ┌─────────────┐
│ Local Machine   │────────▶│ Proxmox Host     │────────▶│ Test VMs    │
│                 │         │                  │         │             │
│ Generate:       │  Copy:  │ Create templates │  VMs    │ Has public  │
│ • Private key   │  Public │ using public key │  get    │ key from    │
│ • Public key    │   key   │ from /tmp/       │  this   │ your local  │
│                 │         │                  │   key   │ machine!    │
│ Run Ansible ────┼─────────┼──────────────────┼────────▶│             │
│ using private   │         │                  │   SSH   │             │
│ key             │         │                  │ works!  │             │
└─────────────────┘         └──────────────────┘         └─────────────┘
```

**Steps:**
1. **Local**: Generate `~/.ssh/ansible_key` + `~/.ssh/ansible_key.pub`
2. **Local → Proxmox**: `scp ~/.ssh/ansible_key.pub root@proxmox:/tmp/`
3. **Proxmox**: Run `create_templates.sh` (uses `/tmp/ansible_key.pub`)
4. **Local**: Run Ansible (uses `~/.ssh/ansible_key` private key)

---

## Step 1: Proxmox Access

**Goal**: Verify you can access Proxmox host

```bash
# Test SSH to Proxmox
ssh root@<proxmox-ip>

# On Proxmox host, verify qm command works
qm list

# List nodes
pvesh get /nodes
```

**Expected**: Successfully connected and can run commands

---

## Step 2: Setup Credentials

**Goal**: Configure API access

```bash
# On your local machine (ansible-pack root)
cd tests/proxmox

# Copy credentials template
cp .proxmox_credentials.example .proxmox_credentials

# Edit with your values
nano .proxmox_credentials
```

**Required values**:
- `PROXMOX_HOST`: Your Proxmox hostname or IP
- `PROXMOX_NODE`: Node name (find with: `pvesh get /nodes | jq -r '.[0].node'`)
- `PROXMOX_USER`: `root@pam` (or your user)
- `PROXMOX_TOKEN_ID`: Create in Proxmox UI (Datacenter → API Tokens)
- `PROXMOX_TOKEN`: Token secret from Proxmox

**If you don't have API token yet**:
1. Open Proxmox web UI: `https://<proxmox-ip>:8006`
2. Go to: Datacenter → Permissions → API Tokens
3. Click "Add"
4. User: `root@pam`, Token ID: `ansible-test`
5. Uncheck "Privilege Separation"
6. Copy the token secret (shown only once!)

**Source credentials**:
```bash
source .proxmox_credentials

# Verify
echo $PROXMOX_HOST
echo $PROXMOX_NODE
echo $PROXMOX_TOKEN_ID
```

---

## Step 3: Environment Check

**Goal**: Detect network bridges and storage

```bash
# On Proxmox host, run check script
cd /tmp
# Copy script to Proxmox
scp -r <path-to-ansible-pack>/tests/proxmox root@<proxmox-ip>:/tmp/

# On Proxmox host
cd /tmp/proxmox/scripts
./check_proxmox.sh
```

**Expected output**:
```
✓ Running on Proxmox host
✓ Proxmox API accessible
✓ Node found: pve (or your node name)
Network bridges:
  vmbr0 (or your bridge)
Storage pools:
  local-lvm (or your storage)
```

**Update credentials** with detected values:
```bash
# Add to .proxmox_credentials
export BRIDGE="vmbr0"      # Use detected bridge
export STORAGE="local-lvm"  # Use detected storage
```

---

## Step 4: SSH Key Setup (CRITICAL!)

**Goal**: Generate SSH key on LOCAL machine and copy to Proxmox

### On Your Local Machine:

```bash
# Check if key exists
ls -la ~/.ssh/ansible_key*

# If not, generate it
ssh-keygen -t ed25519 -f ~/.ssh/ansible_key -N "" -C "ansible@test-vms"

# Verify key created
ls -la ~/.ssh/ansible_key*
# Should show:
#   ansible_key       (private key - stays on local machine)
#   ansible_key.pub   (public key - goes to Proxmox)
```

### Copy Public Key to Proxmox:

```bash
# Copy public key to Proxmox /tmp directory
scp ~/.ssh/ansible_key.pub root@<proxmox-ip>:/tmp/

# Verify it arrived
ssh root@<proxmox-ip> "cat /tmp/ansible_key.pub"
```

**Expected**: Your public key content displayed

**Why this matters:**
- ✅ VMs will have your LOCAL machine's public key
- ✅ Ansible from LOCAL machine can SSH to VMs
- ❌ Without this, Ansible can't connect to test VMs!

---

## Step 5: Install Ansible Collection (Local Machine)

**Goal**: Ensure community.general collection is available

```bash
# Install collection
ansible-galaxy collection install community.general

# Verify
ansible-galaxy collection list | grep community.general
```

**Expected**: `community.general` version 5.0.0+

---

## Step 6: Create VM Templates (Uses Your SSH Key!)

**Goal**: Create Ubuntu 22.04 template with your public key

```bash
# On Proxmox host
cd /tmp/proxmox/scripts
source ../.proxmox_credentials  # If you created it in /tmp/proxmox/

# IMPORTANT: Verify your public key is in /tmp/
ls -la /tmp/ansible_key.pub

# Create templates (this takes ~5-10 minutes)
./create_templates.sh
```

**What happens**:
1. Script looks for SSH key in `/tmp/ansible_key.pub` (your copied key!)
2. Downloads Ubuntu 22.04 cloud image (~700MB)
3. Creates VM with ID 9000
4. **Injects your public key via cloud-init**
5. Converts to template

**Expected output**:
```
✓ Using SSH key from: /tmp/ansible_key.pub (copied from local machine)
✓ SSH key found: /tmp/ansible_key.pub

...

✓✓✓ Template ubuntu-22.04-template created successfully!
```

**If you see warning about SSH key:**
```
⚠ Using SSH key from: /root/.ssh/ansible_key.pub
    Note: This should match your local machine's key for Ansible to work
```
This means it used the Proxmox host's key instead of yours - **go back to Step 4!**

**Verify template created**:
```bash
qm list | grep template
# Should show: 9000    ubuntu-22.04-template    0    0    template
```

**If fails**: Check `/var/log/pve/tasks/` for errors

---

## Step 7: Test VM Creation

**Goal**: Create a test VM manually

```bash
# On Proxmox host
cd /tmp/proxmox/scripts

# Create workstation VM
./setup_vm.sh test-workstation-ubuntu 100 9000
```

**What happens** (~2-3 minutes):
1. Clones template 9000 → VM 100
2. Starts VM
3. Waits for cloud-init
4. Gets VM IP address
5. Tests SSH connectivity

**Expected output**:
```
=========================================
VM Information
=========================================
VM ID: 100
Name: test-workstation-ubuntu
IP Address: 192.168.x.x
Status: running

Access VM:
  ssh -i ~/.ssh/ansible_key ansible@192.168.x.x
=========================================

To use this VM in tests, export:
  export test_workstation_ubuntu_IP="192.168.x.x"

✓ VM test-workstation-ubuntu ready!
```

**Test SSH manually**:
```bash
# Use the IP from output
ssh -i ~/.ssh/ansible_key ansible@<vm-ip>

# Inside VM
whoami  # Should be: ansible
cloud-init status  # Should be: done
exit
```

**If SSH fails**:
- Check VM console: `qm terminal 100`
- Check VM status: `qm status 100`
- Check cloud-init logs: `qm guest exec 100 -- cat /var/log/cloud-init.log`

---

## Step 8: Update Inventory with VM IP

**Goal**: Configure inventory with actual VM IP

```bash
# On your local machine
cd tests/proxmox

# Edit inventory
nano inventory.yml

# Update the ansible_host for test-workstation-ubuntu:
test-workstation-ubuntu:
  ansible_host: "192.168.x.x"  # Use actual IP from Step 7
  vmid: 100
  template: 9000
```

**Or use environment variable**:
```bash
export TEST_WORKSTATION_IP="192.168.x.x"
```

---

## Step 9: Test Ansible Connectivity

**Goal**: Verify Ansible can reach the VM

```bash
# On your local machine
cd tests/proxmox

# Source credentials
source .proxmox_credentials

# Test ping
ansible -i inventory.yml test-workstation-ubuntu -m ping

# Test command
ansible -i inventory.yml test-workstation-ubuntu -m command -a "hostname"
```

**Expected**:
```
test-workstation-ubuntu | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

**If fails**:
- Check inventory.yml ansible_host is correct
- Check SSH key path in inventory
- Test SSH manually first (Step 7)

---

## Step 10: Run Workstation Scenario (Critical Test!)

**Goal**: Run full workstation test scenario

```bash
# On your local machine
cd tests/proxmox

# Run workstation scenario
ansible-playbook -i inventory.yml scenarios/workstation.yml -v
```

**Expected** (~10-15 minutes):
- Installs fonts, utilities, nvim, zsh
- 60+ tasks executed
- 0 failures
- Final output: "All workstation tools installed successfully!"

**Watch for**:
- Cloud-init completion
- Role execution (fonts → utilities → nvim → zsh)
- Final verification assertions

**If fails**:
- Check which role failed
- Review error messages
- Known issues: hardcoded username in nvim (should use `ansible` user)

---

## Step 11: Test Idempotency

**Goal**: Verify second run makes no changes

```bash
# Run again
ansible-playbook -i inventory.yml scenarios/workstation.yml -v
```

**Expected**:
- All tasks show: `ok` (not `changed`)
- `changed=0` in final summary
- Proves roles are idempotent

---

## Step 12: Test Cleanup

**Goal**: Verify VM cleanup works

```bash
# On Proxmox host
cd /tmp/proxmox/scripts

# List VMs
qm list | grep test-

# Cleanup
./cleanup.sh

# Or force without confirmation
./cleanup.sh --force
```

**Expected**:
```
✓ VM 100 deleted
✓ Cleanup complete: 1 VMs deleted
```

**Verify**:
```bash
qm list | grep test-
# Should be empty
```

---

## Summary: Quick Test Sequence

Once everything is set up, you can test the full cycle:

```bash
# On Proxmox host
cd /tmp/proxmox/scripts

# 1. Create VM
./setup_vm.sh test-workstation-ubuntu 100 9000

# Note the IP address
export TEST_WORKSTATION_IP="<ip-from-output>"

# 2. On local machine - Run test
cd tests/proxmox
ansible-playbook -i inventory.yml scenarios/workstation.yml

# 3. Back on Proxmox - Cleanup
cd /tmp/proxmox/scripts
./cleanup.sh --force
```

---

## Troubleshooting

### VM Won't Start
```bash
qm status 100
qm start 100
tail -f /var/log/pve/tasks/active
```

### No IP Address
```bash
# Check guest agent
qm guest cmd 100 network-get-interfaces

# Or get from Proxmox UI
# Or check DHCP leases
```

### SSH Fails
```bash
# Test from Proxmox host
ssh -i ~/.ssh/ansible_key ansible@<vm-ip>

# Check cloud-init
qm guest exec 100 -- cloud-init status --long
```

### Ansible Can't Connect
```bash
# Verify inventory
ansible-inventory -i inventory.yml --list

# Test connection
ansible -i inventory.yml test-workstation-ubuntu -m ping -vvv
```

### Template Creation Fails
```bash
# Check disk space
df -h

# Check download
ls -lh /tmp/proxmox-templates/

# Manual cleanup
rm -rf /tmp/proxmox-templates/
```

---

## Success Criteria

✅ **Layer 3 Infrastructure Working When**:
- [ ] VM template created (ID 9000)
- [ ] Test VM created successfully
- [ ] SSH access works
- [ ] Ansible ping succeeds
- [ ] Workstation scenario runs to completion
- [ ] All assertions pass
- [ ] Second run is idempotent (0 changes)
- [ ] Cleanup removes VM successfully

---

## Next Steps After Success

Once all tests pass:
1. Test server scenario (bootstrap + hardening)
2. Complete Phase 6: TESTING_PROXMOX.md documentation
3. Complete Phase 7: Update main repository docs
4. Mark Layer 3 as ✅ Complete
