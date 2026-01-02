# Testing Strategy Summary

This document provides an overview of the complete 3-layer testing pyramid implemented for the Ansible Pack repository.

## Testing Pyramid

```
                    ╔═══════════════════════════╗
                    ║   Layer 3: Proxmox        ║
                    ║   Acceptance Testing      ║
                    ║   (Full VMs, Production)  ║
                    ╚═══════════════════════════╝
                        15-30 minutes

            ╔═════════════════════════════════════╗
            ║     Layer 2: LXD                    ║
            ║     Integration Testing             ║
            ║     (System containers, Multi-role) ║
            ╚═════════════════════════════════════╝
                      5-10 minutes

    ╔═══════════════════════════════════════════════╗
    ║        Layer 1: Molecule + Docker             ║
    ║        Unit Testing                           ║
    ║        (Process containers, Single role)      ║
    ╚═══════════════════════════════════════════════╝
                    2-3 minutes
```

## Layer 1: Molecule + Docker

**Purpose**: Fast, focused testing of individual Ansible roles

**Technology**: Molecule + Docker + pytest

**Status**: ✅ **IMPLEMENTED AND WORKING**

**What it tests**:
- Individual role functionality
- Role idempotency
- Basic assertions
- Multiple OS versions (Ubuntu, Debian)

**Speed**: 2-3 minutes per role

**Documentation**: `docs/TESTING.md`, `docs/TESTING_QUICKSTART.md`

### Example Usage

```bash
# Test a single role
make test-role ROLE=zsh

# Or use molecule directly
cd roles/zsh
molecule test
```

### Current Status

✅ ZSH role fully tested with Molecule
- Ubuntu 22.04 container: PASSED
- Debian 12 container: PASSED
- Idempotency check: PASSED
- All verification tests: PASSED

### Next Roles to Test

- [ ] nvim
- [ ] utilities
- [ ] fonts
- [ ] bootstrap
- [ ] hardening
- [ ] docker

## Layer 2: LXD

**Purpose**: Integration testing of multiple roles working together

**Technology**: LXD system containers + Ansible

**Status**: ✅ **STRUCTURE IMPLEMENTED, READY TO USE**

**What it tests**:
- Complete playbooks (workstation_setup.yml, server_setup.yml)
- Role interactions
- System-level changes (systemd, networking, users)
- Multi-container scenarios

**Speed**: 5-10 minutes per scenario

**Documentation**: `docs/TESTING_LXD.md`, `tests/lxd/README.md`

### Example Usage

```bash
# Test workstation setup
make lxd-test-workstation

# Test server hardening
make lxd-test-server

# Run all integration tests
make lxd-test-all
```

### Prerequisites

LXD must be installed:
```bash
sudo snap install lxd
sudo usermod -aG lxd $USER
newgrp lxd
sudo lxd init --minimal
```

### Test Scenarios

1. **Workstation** (`tests/lxd/scenarios/workstation.yml`)
   - Tests: fonts, utilities, nvim, zsh, docker
   - Verifies complete workstation environment

2. **Server** (`tests/lxd/scenarios/server.yml`)
   - Tests: bootstrap, hardening
   - Verifies security configurations

## Layer 3: Proxmox

**Purpose**: Final acceptance testing in production-like environment

**Technology**: Proxmox VE + Full VMs + Ansible

**Status**: 📋 **PLANNED**

**What it tests**:
- Complete end-to-end workflows
- Production-like networking
- Real hardware configurations
- Multi-host deployments

**Speed**: 15-30 minutes per scenario

**Environment**: Requires homelab with Proxmox

### Planned Usage

```bash
# Run acceptance tests on Proxmox
make proxmox-test

# Deploy to specific Proxmox host
make proxmox-deploy NODE=pve01
```

## Testing Strategy by Development Phase

### During Development
**Layer 1 (Molecule)**: Run continuously while developing roles
```bash
# Quick feedback loop
cd roles/zsh
molecule converge  # Apply changes
molecule verify    # Check results
```

### Before Committing
**Layer 1 (Molecule)**: Full test of modified roles
```bash
make test-role ROLE=zsh
make lint
```

### Before Merging PR
**Layer 2 (LXD)**: Integration tests
```bash
make lxd-test-all
```

### Before Production Deploy
**Layer 3 (Proxmox)**: Acceptance tests
```bash
make proxmox-test
```

## Testing Comparison

| Aspect | Layer 1 (Molecule) | Layer 2 (LXD) | Layer 3 (Proxmox) |
|--------|-------------------|---------------|-------------------|
| **Container Type** | Process (Docker) | System (LXD) | Full VM |
| **Systemd Support** | Limited | Full | Full |
| **Networking** | Basic | Full | Production-like |
| **Isolation** | Process-level | System-level | Full VM isolation |
| **Speed** | Very Fast (2-3 min) | Fast (5-10 min) | Slower (15-30 min) |
| **Cost** | Free, local | Free, local | Requires homelab |
| **Use Case** | Unit test roles | Integration test | Acceptance test |
| **When to Run** | During development | Before merge | Before production |

## Directory Structure

```
ansible-pack/
├── docs/
│   ├── TESTING.md              # Layer 1 comprehensive guide
│   ├── TESTING_QUICKSTART.md   # Layer 1 quick start
│   ├── TESTING_LXD.md          # Layer 2 comprehensive guide
│   └── TESTING_SUMMARY.md      # This file
│
├── tests/
│   └── lxd/                    # Layer 2 integration tests
│       ├── README.md
│       ├── inventory.yml
│       ├── group_vars/
│       ├── scenarios/
│       │   ├── workstation.yml
│       │   └── server.yml
│       └── scripts/
│           ├── setup_container.sh
│           ├── run_tests.sh
│           └── cleanup.sh
│
└── roles/
    └── zsh/                    # Example role with tests
        ├── tasks/
        ├── files/
        ├── vars/
        └── molecule/           # Layer 1 tests
            └── default/
                ├── molecule.yml
                ├── converge.yml
                ├── verify.yml
                └── prepare.yml
```

## Makefile Commands

### Layer 1 (Molecule)
```bash
make test-role ROLE=zsh          # Test specific role
make test-all                    # Test all roles
make molecule-create ROLE=zsh    # Create test containers
make molecule-converge ROLE=zsh  # Apply role
make molecule-verify ROLE=zsh    # Verify results
make molecule-destroy ROLE=zsh   # Clean up
```

### Layer 2 (LXD)
```bash
make lxd-create NAME=test-workstation  # Create container
make lxd-test-workstation        # Test workstation
make lxd-test-server             # Test server
make lxd-test-all                # Run all tests
make lxd-clean                   # Clean up
make lxd-list                    # List containers
```

### Layer 3 (Proxmox)
```bash
# To be implemented
make proxmox-test
make proxmox-deploy NODE=pve01
```

## CI/CD Integration

### Recommended Pipeline

```yaml
stages:
  - lint
  - unit-test
  - integration-test
  - acceptance-test

lint:
  stage: lint
  script:
    - make lint
    - make syntax-check

unit-test:
  stage: unit-test
  script:
    - make test-all
  # Runs for all commits

integration-test:
  stage: integration-test
  script:
    - make lxd-test-all
  # Runs for PRs only

acceptance-test:
  stage: acceptance-test
  script:
    - make proxmox-test
  # Runs before production deploy
  when: manual
```

## Best Practices

1. **Write tests early**: Add Molecule tests when creating new roles
2. **Keep tests fast**: Layer 1 should complete in under 5 minutes
3. **Test interactions**: Use Layer 2 to test how roles work together
4. **Clean up**: Always clean up test resources after runs
5. **Document failures**: Add common failure patterns to docs
6. **Automate**: Integrate tests into pre-commit hooks and CI/CD

## Troubleshooting

### Layer 1 Issues
- Docker not running: `sudo systemctl start docker`
- Molecule not found: `pip3 install --user molecule molecule-docker`
- Containers won't start: Check Docker logs

### Layer 2 Issues
- LXD not installed: `sudo snap install lxd`
- Permission denied: `sudo usermod -aG lxd $USER && newgrp lxd`
- Container networking: `lxc network list`

### General
- Check documentation: Each layer has detailed troubleshooting guides
- Verbose mode: Add `-v`, `-vv`, or `-vvv` to Ansible commands
- Clean state: Start with `make clean` or `make lxd-clean`

## Metrics and Reporting

### Current Test Coverage

- **Roles with Molecule tests**: 1/6 (zsh)
- **Integration scenarios**: 2 (workstation, server)
- **Supported platforms**: Ubuntu 22.04, Debian 12

### Goals

- [ ] 100% role coverage with Molecule tests
- [x] LXD integration test framework
- [ ] Proxmox acceptance test framework
- [ ] CI/CD pipeline implementation
- [ ] Test coverage reporting
- [ ] Performance benchmarking

## Next Steps

1. **Immediate**: Add Molecule tests to remaining roles
2. **Short-term**: Test LXD scenarios on actual LXD host
3. **Medium-term**: Design and implement Proxmox test scenarios
4. **Long-term**: Full CI/CD integration with automated testing

## Resources

- [Molecule Documentation](https://molecule.readthedocs.io/)
- [LXD Documentation](https://linuxcontainers.org/lxd/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Testing Strategies](https://www.ansible.com/blog/testing-ansible-roles-with-molecule)
