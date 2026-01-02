# Layer 2: LXD Integration Testing

LXD provides system containers that are more realistic than Docker containers, making them ideal for integration testing multiple Ansible roles together.

## Overview

**Purpose**: Test complete playbooks with multiple roles working together in an environment that closely mimics production.

**What we test**:
- Full workstation_setup.yml playbook (multiple roles)
- Full server_setup.yml playbook (bootstrap + hardening)
- Role interactions and dependencies
- System-level changes (systemd, networking, users)

## Prerequisites

### Installing LXD

#### Option 1: Install via Snap (Recommended for Ubuntu)
```bash
# Install LXD
sudo snap install lxd

# Add your user to lxd group
sudo usermod -aG lxd $USER

# Log out and back in, or use:
newgrp lxd

# Initialize LXD (choose defaults for most options)
lxd init --minimal
```

#### Option 2: Install via Apt
```bash
sudo apt update
sudo apt install lxd lxd-client
sudo usermod -aG lxd $USER
newgrp lxd
lxd init --minimal
```

### Verify Installation
```bash
lxc version
lxc list  # Should show empty list initially
```

## Quick Start

### 1. Launch a Test Container

```bash
# Create Ubuntu 22.04 container
lxc launch ubuntu:22.04 test-workstation

# Wait for it to be ready
lxc exec test-workstation -- cloud-init status --wait

# Check it's running
lxc list
```

### 2. Run Workstation Setup Playbook

```bash
# From repository root
cd /home/lblazejowski/repos/irvis/ansible-pack

# Test workstation setup
ansible-playbook -i tests/lxd/inventory.yml playbooks/workstation_setup.yml
```

### 3. Verify Results

```bash
# Connect to container
lxc exec test-workstation -- bash

# Check installations
which zsh
docker --version
nvim --version

# Exit container
exit
```

### 4. Clean Up

```bash
# Stop and delete container
lxc stop test-workstation
lxc delete test-workstation
```

## Test Structure

```
tests/lxd/
├── inventory.yml          # Inventory for LXD containers
├── group_vars/
│   └── lxd_containers.yml # Variables for LXD testing
├── scenarios/
│   ├── workstation.yml    # Test workstation setup
│   ├── server.yml         # Test server hardening
│   └── full_stack.yml     # Test everything together
└── scripts/
    ├── setup_container.sh # Helper to create test containers
    ├── run_tests.sh       # Run all integration tests
    └── cleanup.sh         # Clean up test containers
```

## Test Scenarios

### Scenario 1: Workstation Setup
Tests the complete workstation configuration with all tools.

```bash
./tests/lxd/scripts/setup_container.sh workstation ubuntu:22.04
ansible-playbook -i tests/lxd/inventory.yml tests/lxd/scenarios/workstation.yml
```

### Scenario 2: Server Hardening
Tests bootstrap + hardening roles together.

```bash
./tests/lxd/scripts/setup_container.sh server debian:12
ansible-playbook -i tests/lxd/inventory.yml tests/lxd/scenarios/server.yml
```

### Scenario 3: Multi-Container Testing
Tests multiple containers with different configurations.

```bash
# Create multiple containers
lxc launch ubuntu:22.04 dev-workstation
lxc launch ubuntu:22.04 prod-server

# Run against all
ansible-playbook -i tests/lxd/inventory.yml tests/lxd/scenarios/full_stack.yml
```

## LXD vs Docker vs Proxmox

| Feature | Docker (Layer 1) | LXD (Layer 2) | Proxmox (Layer 3) |
|---------|------------------|---------------|-------------------|
| **Speed** | Very Fast (2-3 min) | Fast (5-10 min) | Slower (15-30 min) |
| **Isolation** | Process-level | System-level | Full VM isolation |
| **Systemd** | Limited | Full support | Full support |
| **Networking** | Basic | Full networking | Production-like |
| **Use Case** | Unit test roles | Integration test playbooks | Acceptance testing |
| **Cost** | Free, local | Free, local | Requires homelab |

## Advanced Usage

### Using LXD Profiles

Create a profile for Ansible testing:

```bash
# Create profile
lxc profile create ansible-test

# Configure it
lxc profile edit ansible-test << EOF
config:
  security.nesting: "true"
  security.privileged: "true"
description: Profile for Ansible testing
devices:
  root:
    path: /
    pool: default
    type: disk
  eth0:
    name: eth0
    network: lxdbr0
    type: nic
name: ansible-test
EOF

# Launch container with profile
lxc launch ubuntu:22.04 test-container -p default -p ansible-test
```

### Snapshot and Restore

```bash
# Create snapshot before testing
lxc snapshot test-workstation pre-test

# Run tests...

# Restore if needed
lxc restore test-workstation pre-test
```

### Copy Containers

```bash
# Create a base container with common setup
lxc launch ubuntu:22.04 base-workstation
lxc exec base-workstation -- apt update && apt upgrade -y

# Snapshot it
lxc snapshot base-workstation clean

# Copy for testing
lxc copy base-workstation test1
lxc copy base-workstation test2
lxc start test1 test2
```

## Troubleshooting

### Container Won't Start
```bash
lxc info test-workstation  # Check status
lxc console test-workstation  # Access console
journalctl -xe  # Check host logs
```

### Network Issues
```bash
# Check LXD network
lxc network list
lxc network show lxdbr0

# Restart LXD network
sudo systemctl restart lxd
```

### Permission Denied
```bash
# Ensure you're in lxd group
groups | grep lxd

# If not, add yourself and re-login
sudo usermod -aG lxd $USER
newgrp lxd
```

## Best Practices

1. **Clean Up**: Always delete test containers when done
2. **Use Snapshots**: Create snapshots before major changes
3. **Consistent Naming**: Use descriptive names (test-*, dev-*, etc.)
4. **Resource Limits**: Set CPU/memory limits for large tests
5. **Regular Updates**: Keep base images updated

## Makefile Integration

The repository Makefile includes LXD testing commands:

```bash
# Create test container
make lxd-create

# Run integration tests
make lxd-test

# Clean up
make lxd-clean

# Full cycle
make lxd-full
```

## CI/CD Integration

LXD tests can run in CI/CD pipelines:

```yaml
# .github/workflows/integration-tests.yml
name: Integration Tests

on: [pull_request]

jobs:
  lxd-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Install LXD
        run: |
          sudo snap install lxd
          sudo lxd init --auto
          sudo usermod -aG lxd $USER

      - name: Run Integration Tests
        run: |
          cd tests/lxd
          ./scripts/run_tests.sh
```

## Next Steps

After LXD integration tests pass:
1. Move to Layer 3 (Proxmox acceptance testing)
2. Set up automated testing in CI/CD
3. Create test reports and metrics
4. Document common failure patterns
