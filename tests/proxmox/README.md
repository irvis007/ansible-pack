# Layer 3: Proxmox Acceptance Testing

Production-like testing using Proxmox VE and full virtual machines.

## Quick Start

```bash
# 1. Setup Proxmox (one-time)
./tests/proxmox/scripts/create_templates.sh

# 2. Run tests
./tests/proxmox/scripts/run_tests.sh workstation
./tests/proxmox/scripts/run_tests.sh server

# 3. Cleanup
./tests/proxmox/scripts/cleanup.sh
```

## Prerequisites

Before running tests, complete the setup:

1. **Proxmox VE** 7.x or 8.x installed and accessible
2. **API Token** created (see [Setup Guide](docs/SETUP_GUIDE.md))
3. **SSH Keys** generated (`~/.ssh/ansible_key`)
4. **Ansible Collection**: `ansible-galaxy collection install community.general`
5. **Credentials**: Configure `tests/proxmox/.proxmox_credentials`

**Detailed setup instructions**: [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md)

---

## Directory Structure

```
tests/proxmox/
├── README.md                    # This file
├── inventory.yml                # VM definitions
├── ansible.cfg                  # Ansible configuration
├── .proxmox_credentials         # API credentials (not in git)
├── group_vars/
│   └── proxmox_vms.yml         # Test variables
├── scenarios/
│   ├── workstation.yml         # Workstation setup test
│   ├── server.yml              # Server hardening test
│   └── common/                 # Shared tasks
├── scripts/
│   ├── create_templates.sh     # One-time template creation
│   ├── setup_vm.sh             # Create individual VM
│   ├── run_tests.sh            # Test orchestration
│   ├── cleanup.sh              # VM cleanup
│   ├── check_proxmox.sh        # Connectivity check
│   └── lib/                    # Shared functions
├── templates/                   # Cloud-init configs
└── docs/
    └── SETUP_GUIDE.md          # Detailed setup
```

---

## Test Scenarios

### Workstation Scenario

Tests complete workstation setup with development tools.

**Roles tested**: fonts, utilities, nvim, zsh
**VM**: test-workstation-ubuntu (VMID 100)
**Duration**: ~10-15 minutes

```bash
./tests/proxmox/scripts/run_tests.sh workstation
```

**Verifies**:
- ✓ ZSH installation and configuration
- ✓ NeoVim with AstroVim
- ✓ Modern CLI utilities (eza, bat, zoxide, etc.)
- ✓ NerdFonts installed and cached

### Server Scenario

Tests server hardening and security configuration.

**Roles tested**: bootstrap, hardening
**VM**: test-server-ubuntu (VMID 101)
**Duration**: ~10 minutes

```bash
./tests/proxmox/scripts/run_tests.sh server
```

**Verifies**:
- ✓ Ansible user created with SSH access
- ✓ Suricata IDS/IPS installed and running
- ✓ Security hardening applied
- ✓ Firewall configuration

### All Scenarios

Run all tests sequentially:

```bash
./tests/proxmox/scripts/run_tests.sh all
```

---

## Usage

### Initial Setup (One-Time)

1. **Configure credentials**:
```bash
# Copy example and edit
cp .proxmox_credentials.example .proxmox_credentials
nano .proxmox_credentials

# Source credentials
source .proxmox_credentials
```

2. **Create VM templates**:
```bash
./scripts/create_templates.sh
```

This creates:
- Template 9000: Ubuntu 22.04 (cloud-init)
- Template 9001: Debian 12 (cloud-init)

### Running Tests

**Single scenario**:
```bash
./scripts/run_tests.sh workstation
./scripts/run_tests.sh server
```

**All scenarios**:
```bash
./scripts/run_tests.sh all
```

**With cleanup**:
```bash
./scripts/run_tests.sh workstation cleanup_yes
```

### Manual VM Management

**Create specific VM**:
```bash
./scripts/setup_vm.sh test-workstation-ubuntu 100 9000
```

**List VMs**:
```bash
./scripts/check_proxmox.sh
```

**Cleanup test VMs**:
```bash
./scripts/cleanup.sh
```

**Force cleanup (no confirmation)**:
```bash
./scripts/cleanup.sh --force
```

---

## Inventory Configuration

Test VMs are defined in `inventory.yml`:

```yaml
test_workstations:
  hosts:
    test-workstation-ubuntu:
      ansible_host: <will-be-detected>
      vmid: 100
      template: 9000  # Ubuntu 22.04
      cores: 2
      memory: 2048

test_servers:
  hosts:
    test-server-ubuntu:
      ansible_host: <will-be-detected>
      vmid: 101
      template: 9000  # Ubuntu 22.04
      cores: 2
      memory: 2048
```

VM IPs are automatically detected after creation via cloud-init.

---

## Troubleshooting

### VM Won't Start

```bash
# Check VM status
qm status <vmid>

# View VM logs
qm terminal <vmid>

# Check Proxmox logs
tail -f /var/log/pve/tasks/active
```

### Cloud-Init Issues

```bash
# Access VM console
qm terminal <vmid>

# Inside VM, check cloud-init status
cloud-init status --long
cloud-init status --wait

# View cloud-init logs
cat /var/log/cloud-init.log
cat /var/log/cloud-init-output.log
```

### SSH Connection Failed

```bash
# Get VM IP
qm guest cmd <vmid> network-get-interfaces

# Test SSH manually
ssh -i ~/.ssh/ansible_key ansible@<vm-ip>

# Check SSH key in VM
qm guest exec <vmid> -- cat /home/ansible/.ssh/authorized_keys
```

### API Connection Issues

```bash
# Test API
./scripts/check_proxmox.sh

# Verify token
echo $PROXMOX_TOKEN

# Test with curl
curl -k -H "Authorization: PVEAPIToken=${PROXMOX_USER}!${PROXMOX_TOKEN_ID}=${PROXMOX_TOKEN}" \
  https://${PROXMOX_HOST}:8006/api2/json/nodes
```

### Template Not Found

```bash
# List templates
pvesh get /cluster/resources --type vm | grep template

# Recreate templates
./scripts/create_templates.sh
```

---

## Differences from Layer 2 (LXD)

| Aspect | LXD (Layer 2) | Proxmox (Layer 3) |
|--------|---------------|-------------------|
| **Environment** | System containers | Full VMs |
| **Boot Time** | ~5 seconds | ~30-60 seconds |
| **Isolation** | System-level | Full VM isolation |
| **Networking** | Direct exec | SSH over network |
| **Hardware** | Shared kernel | Full hardware emulation |
| **Use Case** | Integration testing | Acceptance testing |
| **Frequency** | Multiple times/day | Before production |

---

## Best Practices

1. **Run Layer 1 & 2 first**: Fix issues in faster layers before Layer 3
2. **Clean up regularly**: Don't leave test VMs running
3. **Monitor resources**: VMs consume significant RAM/disk
4. **Use snapshots**: Take snapshots before destructive tests
5. **Separate network**: Consider VLAN for test VMs if possible

---

## Resources

- **Comprehensive Guide**: [docs/TESTING_PROXMOX.md](../../docs/TESTING_PROXMOX.md)
- **Setup Guide**: [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md)
- **Testing Strategy**: [docs/TESTING_SUMMARY.md](../../docs/TESTING_SUMMARY.md)
- **Proxmox API**: https://pve.proxmox.com/pve-docs/api-viewer/
- **Ansible Proxmox Module**: https://docs.ansible.com/ansible/latest/collections/community/general/proxmox_kvm_module.html

---

## Support

If you encounter issues:

1. Check the [Setup Guide](docs/SETUP_GUIDE.md) for prerequisites
2. Review troubleshooting section above
3. Check Proxmox logs: `/var/log/pve/tasks/`
4. Verify credentials: `./scripts/check_proxmox.sh`
5. Open an issue with full error logs

---

**Status**: ✅ Layer 3 infrastructure ready for use
**Last Updated**: 2026-01-02
