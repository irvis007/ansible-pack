# LXD Integration Testing

This directory contains integration tests for the Ansible Pack using LXD containers.

## Overview

Layer 2 testing uses LXD to provide system-level containers that more closely mimic production environments than Docker containers. This allows us to test:

- Complete playbooks with multiple roles
- Role interactions and dependencies
- System-level changes (systemd, networking, user management)
- Multi-container scenarios

## Directory Structure

```
tests/lxd/
├── README.md                    # This file
├── inventory.yml                # Inventory defining test containers
├── group_vars/
│   └── lxd_containers.yml      # Variables for LXD testing
├── scenarios/
│   ├── workstation.yml         # Test workstation setup playbook
│   └── server.yml              # Test server hardening playbook
└── scripts/
    ├── setup_container.sh      # Create and prepare LXD containers
    ├── run_tests.sh            # Run integration test suite
    └── cleanup.sh              # Clean up test containers
```

## Quick Start

### Prerequisites

1. **Install LXD**:
   ```bash
   sudo snap install lxd
   sudo usermod -aG lxd $USER
   newgrp lxd
   sudo lxd init --minimal
   ```

2. **Verify Installation**:
   ```bash
   lxc version
   ```

### Running Tests

#### Using Makefile (Recommended)

```bash
# Run workstation tests
make lxd-test-workstation

# Run server tests
make lxd-test-server

# Run all tests
make lxd-test-all

# Clean up
make lxd-clean
```

#### Using Scripts Directly

```bash
# Create a test container
./scripts/setup_container.sh test-workstation-ubuntu ubuntu:22.04

# Run specific test scenario
./scripts/run_tests.sh workstation

# Run all tests
./scripts/run_tests.sh all

# Clean up
./scripts/cleanup.sh
```

## Test Scenarios

### Workstation Test
**File**: `scenarios/workstation.yml`

Tests the complete workstation configuration:
- Fonts installation
- Utilities (zoxide, bat, etc.)
- NeoVim with AstroVim
- ZSH with Oh-My-Zsh and plugins
- Docker (optional)

**Hosts**: `test_workstations` group

### Server Test
**File**: `scenarios/server.yml`

Tests server hardening:
- Bootstrap role (ansible user, SSH keys, sudo)
- Hardening role (UFW, fail2ban, SSH config)
- Security configurations

**Hosts**: `test_servers` group

## Inventory Configuration

The `inventory.yml` defines test containers:

```yaml
test_workstations:
  hosts:
    test-workstation-ubuntu:
      ansible_host: test-workstation-ubuntu
      lxd_image: ubuntu:22.04
      install_docker: true
      install_nvim: true
      install_zsh: true
```

### Connection Method

LXD containers use `ansible_connection: lxd`, which connects directly to containers without SSH.

## Variables

Common variables in `group_vars/lxd_containers.yml`:

- `environment_name: testing` - Marks this as test environment
- `sudo_passwordless_allowed: true` - Simplified for testing
- `ufw_enabled: false` - Firewall disabled for easier testing
- `test_user: testuser` - User created during tests

## Scripts

### setup_container.sh

Creates and prepares an LXD container for Ansible testing.

**Usage**:
```bash
./scripts/setup_container.sh [CONTAINER_NAME] [IMAGE]
```

**Example**:
```bash
./scripts/setup_container.sh test-debian debian:12
```

**What it does**:
1. Launches LXD container from specified image
2. Waits for cloud-init to complete
3. Installs Python3 (required for Ansible)
4. Configures sudo
5. Displays container information

### run_tests.sh

Runs integration test scenarios.

**Usage**:
```bash
./scripts/run_tests.sh [SCENARIO] [CLEANUP]
```

**Scenarios**:
- `workstation` - Test workstation setup only
- `server` - Test server hardening only
- `all` - Run all tests (default)

**Cleanup**:
- `yes` - Clean up containers after tests (default)
- `no` - Keep containers for debugging

**Example**:
```bash
# Run workstation tests, keep containers
./scripts/run_tests.sh workstation no

# Run all tests, clean up after
./scripts/run_tests.sh all yes
```

### cleanup.sh

Cleans up test containers.

**Usage**:
```bash
./scripts/cleanup.sh [--images]
```

**Options**:
- `--images` - Also clean up unused images

**What it cleans**:
- Containers matching patterns: `test-*`, `dev-*`, `minimal-*`
- Optionally unused images

## Debugging

### View Container Status
```bash
lxc list
lxc info test-workstation-ubuntu
```

### Access Container
```bash
lxc exec test-workstation-ubuntu -- bash
```

### View Container Logs
```bash
lxc console test-workstation-ubuntu --show-log
```

### Run Single Task
```bash
ansible -i inventory.yml test-workstation-ubuntu -m ping
ansible -i inventory.yml test-workstation-ubuntu -m command -a "zsh --version"
```

### Keep Container for Debugging
```bash
# Run tests without cleanup
./scripts/run_tests.sh workstation no

# Then access container
lxc exec test-workstation-ubuntu -- bash
```

## Best Practices

1. **Clean State**: Always start with fresh containers for consistent results
2. **Snapshots**: Create snapshots before major changes for quick rollback
3. **Resource Limits**: Set limits for CPU/memory if running many containers
4. **Regular Cleanup**: Remove old test containers regularly
5. **Image Updates**: Keep base images updated

## Troubleshooting

### LXD Not Installed
```
ERROR: LXD is not installed
```
**Solution**: Install with `sudo snap install lxd`

### Permission Denied
```
Error: Get "http://unix.socket/1.0": dial unix /var/snap/lxd/common/lxd/unix.socket: connect: permission denied
```
**Solution**: Add yourself to lxd group and re-login
```bash
sudo usermod -aG lxd $USER
newgrp lxd
```

### Container Won't Start
**Check status**:
```bash
lxc info test-workstation-ubuntu
journalctl -xe  # On host
```

**Restart LXD**:
```bash
sudo systemctl restart lxd
```

### Network Issues
```bash
lxc network list
lxc network show lxdbr0
```

## Integration with CI/CD

See `docs/TESTING_LXD.md` for details on integrating LXD tests into CI/CD pipelines.

## Next Steps

After LXD tests pass:
1. Proceed to Layer 3 (Proxmox) for acceptance testing
2. Set up automated testing in CI/CD
3. Add more test scenarios as needed
4. Document failure patterns and solutions
