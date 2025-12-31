# Testing Guide

This guide covers all testing layers for the ansible-pack repository.

## Testing Pyramid

```
┌─────────────────────────────────────────────────────────┐
│ Layer 3: Acceptance Testing (Proxmox VMs)              │
│ Speed: 10-15 minutes | Frequency: Before merge         │
│ Purpose: Manual validation, actual software usage      │
└─────────────────────────────────────────────────────────┘
                          ↑
┌─────────────────────────────────────────────────────────┐
│ Layer 2: Integration Testing (LXD Containers)           │
│ Speed: 2-3 minutes | Frequency: Before commit (5x/day) │
│ Purpose: Full playbook runs, service checks            │
└─────────────────────────────────────────────────────────┘
                          ↑
┌─────────────────────────────────────────────────────────┐
│ Layer 1: Unit Testing (Docker + Molecule)              │
│ Speed: 30 seconds | Frequency: Every change (50x/day)  │
│ Purpose: Syntax, idempotency, basic functionality      │
└─────────────────────────────────────────────────────────┘
```

---

## Layer 1: Docker + Molecule (Unit Testing)

### Overview

Molecule is the industry standard for testing Ansible roles. It uses Docker containers to quickly test roles in isolated environments.

**Benefits**:
- ⚡ Fast (30 seconds per role)
- 🔄 Repeatable and isolated
- 🐳 Uses Docker (lightweight)
- ✅ Tests multiple OS versions simultaneously
- 🔍 Validates idempotency automatically

### Prerequisites

```bash
# Install Python 3.8+
python3 --version

# Install Docker
sudo apt install docker.io
sudo usermod -aG docker $USER
# Log out and back in for group changes

# Verify Docker works
docker run hello-world
```

### Installation

```bash
# Create Python virtual environment (recommended)
python3 -m venv ~/.venv/ansible-testing
source ~/.venv/ansible-testing/bin/activate

# Install Molecule with Docker support
pip install molecule molecule-docker ansible ansible-lint yamllint

# Verify installation
molecule --version
```

### Quick Start

#### 1. Test an Existing Role

```bash
# Navigate to a role with Molecule tests
cd roles/zsh

# Run full test sequence
molecule test

# Or run individual steps:
molecule create    # Create Docker container
molecule converge  # Run the role
molecule verify    # Run verification tests
molecule destroy   # Cleanup
```

#### 2. Interactive Development

```bash
cd roles/zsh

# Create container and keep it running
molecule create

# Apply role (can run multiple times)
molecule converge

# Make changes to role...
# Re-apply to test
molecule converge

# Run verification
molecule verify

# Shell into container for debugging
molecule login

# Cleanup when done
molecule destroy
```

### Molecule Directory Structure

```
roles/zsh/
├── molecule/
│   └── default/              # Test scenario name
│       ├── molecule.yml      # Main config (Docker, platforms)
│       ├── converge.yml      # Playbook that runs the role
│       ├── verify.yml        # Verification tests (optional)
│       └── prepare.yml       # Pre-setup tasks (optional)
├── tasks/
├── defaults/
└── ...
```

### Configuration Files

#### molecule.yml

Defines test infrastructure:

```yaml
---
dependency:
  name: galaxy

driver:
  name: docker

platforms:
  - name: ubuntu22-test
    image: geerlingguy/docker-ubuntu2204-ansible:latest
    pre_build_image: true
    privileged: true
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:ro

  - name: debian12-test
    image: geerlingguy/docker-debian12-ansible:latest
    pre_build_image: true
    privileged: true
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:ro

provisioner:
  name: ansible
  config_options:
    defaults:
      callbacks_enabled: profile_tasks
      stdout_callback: yaml

verifier:
  name: ansible
```

#### converge.yml

Playbook that applies the role:

```yaml
---
- name: Converge
  hosts: all
  become: false
  gather_facts: true

  tasks:
    - name: Include role
      ansible.builtin.include_role:
        name: zsh
```

#### verify.yml (optional)

Tests to verify the role worked:

```yaml
---
- name: Verify
  hosts: all
  gather_facts: true

  tasks:
    - name: Check if ZSH is installed
      ansible.builtin.command: zsh --version
      changed_when: false

    - name: Check if Oh-My-Zsh is installed
      ansible.builtin.stat:
        path: ~/.oh-my-zsh
      register: ohmyzsh_dir

    - name: Verify Oh-My-Zsh installation
      ansible.builtin.assert:
        that:
          - ohmyzsh_dir.stat.exists
        fail_msg: "Oh-My-Zsh not installed"
        success_msg: "Oh-My-Zsh installed successfully"
```

### Test Sequence

When you run `molecule test`, it executes:

1. **Lint**: Runs ansible-lint and yamllint
2. **Destroy**: Removes any existing test containers
3. **Dependency**: Installs role dependencies
4. **Syntax**: Validates playbook syntax
5. **Create**: Creates Docker containers
6. **Prepare**: Runs prepare.yml (if exists)
7. **Converge**: Applies the role
8. **Idempotence**: Runs role again, expects no changes
9. **Verify**: Runs verification tests
10. **Destroy**: Cleans up containers

### Common Workflows

#### Daily Development

```bash
# Quick iteration
cd roles/myrolemolecule create       # Once
molecule converge    # Many times as you develop
molecule verify      # Check if it works
molecule destroy     # When done

# Full test before commit
molecule test
```

#### Testing Multiple OS

```yaml
# In molecule.yml, add more platforms:
platforms:
  - name: ubuntu-20
    image: geerlingguy/docker-ubuntu2004-ansible:latest
  - name: ubuntu-22
    image: geerlingguy/docker-ubuntu2204-ansible:latest
  - name: debian-11
    image: geerlingguy/docker-debian11-ansible:latest
  - name: debian-12
    image: geerlingguy/docker-debian12-ansible:latest
```

```bash
# Test all platforms
molecule test

# Test specific platform
molecule converge -s default -- --limit ubuntu-20
```

### Troubleshooting

#### Container Won't Start

```bash
# Check Docker is running
docker ps

# Check Docker logs
docker logs <container-id>

# Clean up old containers
docker container prune
```

#### Role Fails in Molecule but Works Manually

Common issues:
- Container lacks systemd (use privileged containers)
- Missing dependencies (add to prepare.yml)
- User-specific paths (container runs as different user)

```yaml
# Fix: Use privileged containers
platforms:
  - name: ubuntu22
    privileged: true
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:ro
```

#### Idempotence Test Fails

The role is making changes on second run:

```bash
# Run converge twice manually to debug
molecule converge
molecule converge  # Should show "changed=0"

# Add changed_when: false to non-changing tasks
- name: Check version
  command: myapp --version
  register: version
  changed_when: false
```

### Docker Images

Use official Ansible-ready images:

**Ubuntu**:
- `geerlingguy/docker-ubuntu2004-ansible:latest` (20.04)
- `geerlingguy/docker-ubuntu2204-ansible:latest` (22.04)
- `geerlingguy/docker-ubuntu2404-ansible:latest` (24.04)

**Debian**:
- `geerlingguy/docker-debian11-ansible:latest` (Bullseye)
- `geerlingguy/docker-debian12-ansible:latest` (Bookworm)

**Other**:
- `geerlingguy/docker-rockylinux9-ansible:latest`
- `geerlingguy/docker-fedora39-ansible:latest`

### Best Practices

1. **Keep tests fast**: Remove unnecessary tasks from converge.yml
2. **Test idempotency**: Ensure roles can run multiple times safely
3. **Verify important outcomes**: Add verify.yml for critical functionality
4. **Use prepare.yml**: Install test dependencies separately
5. **Test multiple OS**: Add platforms gradually as needed
6. **Clean up**: Always destroy containers after testing
7. **Cache dependencies**: Use pre-built images when possible

### CI/CD Integration

Add to `.github/workflows/test.yml`:

```yaml
name: Molecule Tests

on: [push, pull_request]

jobs:
  molecule:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        role:
          - zsh
          - nvim
          - utilities

    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          pip install molecule molecule-docker ansible ansible-lint

      - name: Run Molecule tests
        run: |
          cd roles/${{ matrix.role }}
          molecule test
```

### Next Steps

Once Molecule tests are working:

1. Add tests to all roles
2. Set up CI/CD (GitHub Actions)
3. Move to Layer 2: LXD integration tests
4. Move to Layer 3: Proxmox acceptance tests

---

## Layer 2: Integration Testing (LXD)

See [LXD Testing Guide](TESTING_LXD.md) (coming soon)

---

## Layer 3: Acceptance Testing (Proxmox)

See [Proxmox Testing Guide](TESTING_PROXMOX.md) (coming soon)

---

## Quick Reference

```bash
# Layer 1: Molecule (30 sec, run 50x/day)
cd roles/zsh && molecule test

# Layer 2: LXD (2 min, run 5x/day)
make lxd-test-workstation

# Layer 3: Proxmox (10 min, run before merge)
make proxmox-test-workstation
make proxmox-smoke-test
```

## Troubleshooting All Layers

### General Tips

1. Always test syntax first: `ansible-playbook playbook.yml --syntax-check`
2. Use check mode for dry runs: `--check --diff`
3. Enable verbose output for debugging: `-vvv`
4. Check logs in `/var/log/` on target systems
5. Verify connectivity: `ansible all -m ping`

### Getting Help

- **Molecule Issues**: https://molecule.readthedocs.io/
- **Ansible Issues**: https://docs.ansible.com/
- **Docker Issues**: https://docs.docker.com/
- **This Repo**: Create issue on GitHub
