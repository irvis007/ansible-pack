# Testing Guide

Complete testing guide for ansible-pack, covering all three testing layers.

## Table of Contents

- [Testing Strategy](#testing-strategy)
- [Layer 1: Molecule + Docker (Unit Tests)](#layer-1-molecule--docker-unit-tests)
- [Layer 2: LXD (Integration Tests)](#layer-2-lxd-integration-tests)
- [Layer 3: Proxmox (Acceptance Tests)](#layer-3-proxmox-acceptance-tests)
- [Critical Findings & Solutions](#critical-findings--solutions)
- [Quick Reference](#quick-reference)

---

## Testing Strategy

### Three-Layer Testing Pyramid

**Layer 1: Molecule + Docker (Unit Tests)**
- Speed: ~30 seconds per role
- Tests single role in isolation
- Multiple OS versions (Ubuntu, Debian)
- Validates idempotency
- Use during active development

**Layer 2: LXD (Integration Tests)**
- Speed: ~5-10 minutes per scenario
- Tests complete playbooks
- Full OS with systemd, networking
- Multiple roles working together
- Use before committing/merging

**Layer 3: Proxmox (Acceptance Tests)**
- Speed: ~15-30 minutes per scenario
- Full VMs with real hardware emulation
- Production-like environment
- Complete end-to-end validation
- Use before production deployment

### When to Use Each Layer

| Phase | Layer 1 | Layer 2 | Layer 3 |
|-------|---------|---------|---------|
| Writing code | ✅ Continuous | ❌ | ❌ |
| Before commit | ✅ All roles | ❌ | ❌ |
| Before PR merge | ✅ All roles | ✅ Scenarios | ❌ |
| Before deploy | ✅ All roles | ✅ Scenarios | ✅ Full test |

---

## Layer 1: Molecule + Docker (Unit Tests)

### Overview

Molecule is the industry standard for testing Ansible roles. Fast, repeatable, and isolated.

### Prerequisites

```bash
# Install Docker
sudo apt install docker.io
sudo usermod -aG docker $USER
# Log out and back in

# Verify Docker
docker run hello-world
```

### Installation

```bash
# Option 1: Global install (easiest)
make install-molecule

# Option 2: Virtual environment (recommended)
python3 -m venv ~/.venv/ansible-testing
source ~/.venv/ansible-testing/bin/activate
pip install molecule molecule-docker ansible ansible-lint yamllint

# Verify
molecule --version
```

### Quick Start

```bash
# Test an existing role
make test-role ROLE=zsh

# Or manually
cd roles/zsh
molecule test  # Full test cycle

# Interactive development
molecule create    # Create container
molecule converge  # Apply role
molecule verify    # Run tests
molecule destroy   # Cleanup
```

### Common Workflows

**1. Quick iteration during development:**
```bash
cd roles/zsh
molecule create           # Once per session
molecule converge         # After each change
molecule verify           # Check if it works
```

**2. Test before committing:**
```bash
make test-role ROLE=zsh
make lint
make syntax-check
```

**3. Test all roles:**
```bash
make test-all  # Tests all roles with Molecule
```

### Understanding Molecule Output

**Successful run:**
```
PLAY RECAP *****************************
zsh-ubuntu22: ok=15 changed=0 unreachable=0 failed=0
zsh-debian12: ok=15 changed=0 unreachable=0 failed=0

✓ Role zsh tests passed
```
- `changed=0` means idempotent (good!)
- `failed=0` means no errors

**Idempotency failure:**
```
TASK [Install ZSH] ****
changed: [zsh-ubuntu22]  ← Bad! Changed on second run

CRITICAL: Idempotence test failed
```
**Fix**: Add `changed_when: false` to tasks that don't actually change anything

### Troubleshooting

**"Cannot connect to Docker daemon":**
```bash
sudo systemctl start docker
sudo usermod -aG docker $USER
# Log out and back in
```

**"Module not found":**
```bash
ansible-galaxy collection install -r meta/requirements.yml
```

**Idempotency failures:**
- Find the task that changed
- Add `changed_when: false` if it's just checking state
- Make task truly idempotent (check before changing)

---

## Layer 2: LXD (Integration Tests)

### Overview

LXD provides system containers that are more realistic than Docker. Perfect for testing complete playbooks with multiple roles.

### Prerequisites

```bash
# Install LXD
sudo snap install lxd

# Add user to lxd group
sudo usermod -aG lxd $USER
newgrp lxd

# Initialize (accept defaults)
lxd init --minimal

# Verify
lxc version
lxc list
```

### Network Configuration (Important!)

LXD containers need internet access. If ping fails, configure networking:

```bash
# 1. Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf

# 2. Get your network interface (e.g., eth0, enp0s3)
ip route | grep default
# Example output: default via 192.168.1.1 dev eth0

# 3. Add NAT rule (replace eth0 with your interface)
sudo iptables -t nat -A POSTROUTING -s 10.100.100.0/24 -o eth0 -j MASQUERADE

# 4. Allow forwarding
sudo iptables -I FORWARD 1 -s 10.100.100.0/24 -j ACCEPT
sudo iptables -I FORWARD 1 -d 10.100.100.0/24 -j ACCEPT

# 5. Test from a container
lxc launch ubuntu:22.04 test
lxc exec test -- ping -c 2 8.8.8.8
# Should work now

# 6. Clean up test
lxc delete test --force
```

**Make rules persistent:**
```bash
sudo apt install iptables-persistent
sudo netfilter-persistent save
```

### Quick Start

```bash
# 1. Launch container
lxc launch ubuntu:22.04 test-workstation

# Wait for cloud-init
lxc exec test-workstation -- cloud-init status --wait

# 2. Run playbook
ansible-playbook -i tests/lxd/inventory.yml \
  playbooks/workstation_setup.yml

# 3. Verify
lxc exec test-workstation -- bash
# Inside container:
which zsh
nvim --version
exit

# 4. Clean up
lxc delete test-workstation --force
```

### Using Makefile Commands

```bash
# Test workstation setup
make lxd-test-workstation

# Test server setup
make lxd-test-server

# Run all LXD tests
make lxd-test-all

# Clean up all test containers
make lxd-clean

# List containers
make lxd-list
```

### Test Scenarios

**Workstation Scenario** (`tests/lxd/scenarios/workstation.yml`):
- Fonts, utilities, nvim, zsh
- Complete dev environment
- ~5 minutes

**Server Scenario** (`tests/lxd/scenarios/server.yml`):
- Bootstrap, hardening (fail2ban, UFW)
- Security configurations
- ~7 minutes

### Troubleshooting

**Container can't reach internet:**
- See Network Configuration section above
- Check: `lxc exec CONTAINER -- ping 8.8.8.8`

**"No such file or directory: 'fc-cache'":**
- Missing dependencies in fonts role
- Workaround: Add to pre_tasks:
  ```yaml
  pre_tasks:
    - name: Install dependencies
      apt:
        name: [unzip, fontconfig, curl, wget, git]
  ```

**Container won't start:**
```bash
lxc list  # Check status
lxc info CONTAINER  # Get details
lxc console CONTAINER  # Access console
```

---

## Layer 3: Proxmox (Acceptance Tests)

### Overview

Full VMs on Proxmox for production-like testing. Most realistic but slowest.

### Prerequisites

- Proxmox VE 7.x or 8.x server
- SSH access to Proxmox host
- Ansible installed on local machine

### One-Time Setup

**1. Generate SSH keys (local machine):**
```bash
ssh-keygen -t ed25519 -f ~/.ssh/ansible_key -N ""
```

**2. Copy public key to Proxmox:**
```bash
scp ~/.ssh/ansible_key.pub root@<proxmox-ip>:/tmp/
```

**3. Create VM templates (on Proxmox host):**
```bash
ssh root@<proxmox-ip>
cd /tmp/proxmox/scripts
./create_templates.sh
```

This creates cloud-init templates for:
- Ubuntu 22.04 (template ID: 9000)
- Debian 12 (template ID: 9001)

**4. Configure inventory (local machine):**
```bash
vim tests/proxmox/inventory.yml
# Update with your Proxmox host IP
```

### Running Tests

**Create test VM:**
```bash
# On Proxmox host
ssh root@<proxmox-ip>
cd /tmp/proxmox/scripts
./setup_vm.sh test-workstation-ubuntu 100 9000

# Wait for VM to boot and get IP
./get_vm_ip.sh 100
```

**Run test playbook:**
```bash
# On local machine
cd tests/proxmox
ansible-playbook -i inventory.yml scenarios/workstation.yml
```

**Clean up:**
```bash
# On Proxmox host
cd /tmp/proxmox/scripts
./cleanup.sh  # Destroys all test VMs
```

### Test Scenarios

**Workstation** (`tests/proxmox/scenarios/workstation.yml`):
- Complete workstation setup
- ~10-15 minutes

**Server** (`tests/proxmox/scenarios/server.yml`):
- Bootstrap + full hardening
- ~10 minutes

### Validation Checklist

After running playbook, manually verify:

```bash
# SSH into VM
ssh ansible@<vm-ip>

# Check installations
zsh --version
nvim --version
docker --version
bat --version

# Check ZSH configuration
cat ~/.zshrc | grep plugins

# Check Oh-My-Zsh
ls -la ~/.oh-my-zsh/

# Test Neovim
nvim  # Should open without errors

# For servers, check hardening
sudo systemctl status fail2ban
sudo ufw status
```

---

## Critical Findings & Solutions

### 🔥 Critical Issues

**1. Hardcoded Username in nvim Role**

**Problem:**
```yaml
# roles/nvim/tasks/nodejs.yml:4
nodejs_install_npm_user: ukasz  # Hardcoded!
```

**Impact**: Role fails on all systems except developer's machine

**Solution:**
```yaml
# Use variable
nodejs_install_npm_user: "{{ ansible_user_id | default('root') }}"
```

**Status**: ⚠️ **NEEDS FIX** - Update role

---

### ⚠️ High Priority Issues

**2. Missing Dependencies in fonts Role**

**Problem:** Role fails with:
```
Unable to find required 'unzip' binary
No such file or directory: 'fc-cache'
```

**Solution:** Add to role dependencies:
```yaml
- name: Install font dependencies
  apt:
    name:
      - unzip
      - fontconfig
```

**Workaround:** Add to playbook pre_tasks until role is fixed

---

**3. LXD Network Configuration**

**Problem:** Containers can't reach internet

**Solution:** See Layer 2 Network Configuration section above

**Impact:** All LXD tests fail without proper network setup

---

### ✅ Test Results Summary

| Role | Molecule | LXD | Notes |
|------|----------|-----|-------|
| zsh | ✅ Pass | ✅ Pass | No issues |
| utilities | ✅ Pass | ✅ Pass | No issues |
| nvim | ⚠️ Pass* | ⚠️ Pass* | Hardcoded username |
| fonts | ⚠️ Pass* | ⚠️ Pass* | Missing dependencies |
| bootstrap | ❌ No tests | ✅ Pass | Need Molecule |
| hardening | ❌ No tests | ✅ Pass | Need Molecule |

*Pass with workarounds applied

---

## Quick Reference

### Makefile Commands

```bash
# Molecule (Layer 1)
make install-molecule          # One-time setup
make test-role ROLE=zsh       # Test specific role
make test-all                  # Test all roles
make molecule-create ROLE=zsh  # Create container
make molecule-converge ROLE=zsh # Apply role
make molecule-destroy ROLE=zsh # Clean up

# LXD (Layer 2)
make lxd-test-workstation     # Test workstation
make lxd-test-server          # Test server
make lxd-test-all             # Run all tests
make lxd-clean                # Delete all containers
make lxd-list                 # List containers

# Code Quality
make lint                     # ansible-lint + yamllint
make syntax-check             # Playbook syntax
make pre-commit               # Run all checks
```

### Manual Commands

```bash
# Molecule
cd roles/zsh && molecule test

# LXD
lxc launch ubuntu:22.04 test
lxc exec test -- bash
lxc delete test --force

# Proxmox
ssh root@proxmox
cd /tmp/proxmox/scripts
./setup_vm.sh test 100 9000
./cleanup.sh

# Ansible
ansible-playbook playbooks/workstation_setup.yml --check
ansible-playbook playbooks/server_setup.yml --syntax-check
ansible-lint roles/zsh
```

### Verification Commands

```bash
# Test network connectivity
lxc exec CONTAINER -- ping -c 2 8.8.8.8

# Check installed tools
lxc exec CONTAINER -- zsh --version
lxc exec CONTAINER -- nvim --version
lxc exec CONTAINER -- which bat eza fd

# Verify fonts
lxc exec CONTAINER -- fc-list | grep Envy

# Check ZSH configuration
lxc exec CONTAINER -- cat /root/.zshrc

# Check Oh-My-Zsh plugins
lxc exec CONTAINER -- ls -la /root/.oh-my-zsh/custom/plugins/
```

### Common Issues & Fixes

| Issue | Command | Solution |
|-------|---------|----------|
| Docker not running | `sudo systemctl start docker` | Start Docker service |
| LXD permission denied | `newgrp lxd` | Refresh group membership |
| Container no internet | See Layer 2 Network section | Configure iptables |
| Idempotency failed | Check output for `changed:` | Add `changed_when: false` |
| Module not found | `ansible-galaxy collection install -r meta/requirements.yml` | Install collections |

---

## Next Steps

### Immediate Tasks
1. ✅ ZSH role has Molecule tests
2. ⏳ Add Molecule tests to other roles (nvim, utilities, fonts)
3. ⏳ Fix hardcoded username in nvim role
4. ⏳ Add dependencies to fonts role

### Short-Term Goals
- Expand LXD test coverage (more scenarios)
- Document Proxmox setup more thoroughly
- Create automated network setup script for LXD
- Add validation playbook for post-deployment checks

### Long-Term Goals
- CI/CD pipeline with automated testing
- Test coverage reporting
- Performance benchmarking
- Multi-OS testing (Fedora, Arch)

---

## Getting Help

- Check [HOW-TO.md](HOW-TO.md) for practical use cases
- Check [ARCHITECTURE.md](ARCHITECTURE.md) for design decisions
- Check [REFERENCE.md](REFERENCE.md) for variable documentation
- Open an issue with test output and error messages

---

*Last updated: 2026-02-10*
