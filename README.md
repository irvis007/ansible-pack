# Ansible Pack - Workstation & Server Automation

Ansible playbooks for automated setup of development workstations and secure servers. Supports Ubuntu and Debian-based systems.

## Features

### Workstation Setup

- **Development Tools**: Docker, AstroVim (Neovim), ZSH with Oh-My-Zsh
- **CLI Utilities**: bat, eza, fd, ripgrep, tmux, lazygit, zoxide
- **Fonts**: Nerd Fonts (EnvyCodeR)
- **Shell**: ZSH with plugins (autosuggestions, syntax-highlighting, completions)

### Server Hardening

- **Firewall**: UFW with configurable rules
- **Intrusion Prevention**: fail2ban configuration
- **IDS/IPS**: Suricata (optional)
- **Automatic Updates**: Unattended upgrades
- **SSH Hardening**: Custom ports, key-based auth

## Quick Start

### Prerequisites

```bash
# Install Ansible
sudo apt install ansible

# Clone this repository
git clone <your-repo-url>
cd ansible-pack
```

### Initial Setup

```bash
# Install required collections and roles
ansible-galaxy collection install -r meta/requirements.yml
ansible-galaxy role install -r meta/requirements.yml
```

### Configuration

1. **Create your inventory file**:

```bash
# For development/testing
cp inventories/development/hosts.yml.example inventories/development/hosts.yml
# Edit and add your hosts
vim inventories/development/hosts.yml

# For production
cp inventories/production/hosts.yml.example inventories/production/hosts.yml
vim inventories/production/hosts.yml
```

2. **Configure variables** in environment-specific `group_vars/`:

```yaml
# inventories/development/group_vars/all/common.yml
ansible_ssh_public_key_file: "{{ lookup('env', 'HOME') }}/.ssh/ansible_key.pub"
ssh_custom_port: 22  # Default for development

# inventories/production/group_vars/all/common.yml
ssh_custom_port: 65522  # Custom port for production
sudo_passwordless_allowed: false  # Require password
```

3. **For production**, create encrypted vault:

```bash
cp inventories/production/group_vars/all/vault.yml.example \
   inventories/production/group_vars/all/vault.yml
ansible-vault encrypt inventories/production/group_vars/all/vault.yml
```

### Run Playbooks

```bash
# Development: Setup workstation on localhost
ansible-playbook playbooks/workstation_setup.yml --ask-become-pass

# Development: Setup test server
ansible-playbook playbooks/server_setup.yml \
  -i inventories/development/hosts.yml \
  -l test-server \
  --ask-become-pass

# Production: Setup workstation
ansible-playbook playbooks/workstation_setup.yml \
  -i inventories/production/hosts.yml \
  -l my-laptop \
  --ask-become-pass

# Production: Setup server with vault
ansible-playbook playbooks/server_setup.yml \
  -i inventories/production/hosts.yml \
  -l web-prod-01 \
  --ask-vault-pass \
  --ask-become-pass

# Run specific components only
ansible-playbook playbooks/workstation_setup.yml --tags "zsh,nvim"
```

## Repository Structure

```
ansible-pack/
├── inventories/                 # Environment-specific inventories
│   ├── development/
│   │   ├── hosts.yml           # Dev hosts (gitignored)
│   │   ├── hosts.yml.example   # Example template
│   │   └── group_vars/
│   │       ├── all/
│   │       │   ├── common.yml  # Common dev variables
│   │       │   └── vault.yml.example
│   │       ├── workstations/
│   │       │   └── main.yml    # Dev workstation config
│   │       └── servers/
│   │           └── main.yml    # Dev server config
│   ├── production/
│   │   ├── hosts.yml           # Prod hosts (gitignored)
│   │   ├── hosts.yml.example
│   │   └── group_vars/
│   │       ├── all/
│   │       ├── workstations/
│   │       └── servers/
│   └── README.md               # Inventory documentation
│
├── playbooks/                   # All playbooks
│   ├── workstation_setup.yml   # Workstation configuration
│   ├── server_setup.yml        # Server hardening & setup
│   ├── site.yml                # Main entry point
│   └── README.md               # Playbook documentation
│
├── roles/                       # Ansible roles
│   ├── bootstrap/              # Bootstrap ansible user
│   ├── fonts/                  # Install Nerd Fonts
│   ├── hardening/              # Server security hardening
│   ├── nvim/                   # Neovim + AstroVim
│   ├── utilities/              # CLI tools
│   └── zsh/                    # ZSH + Oh-My-Zsh
│
├── group_vars/                 # Legacy (moved to inventories/)
│   └── all/
│       ├── common.yml
│       └── vault.yml.example
│
├── meta/
│   └── requirements.yml        # External collections/roles
│
├── ansible.cfg                 # Ansible configuration
├── .gitignore                  # Git ignore rules
└── README.md                   # This file
```

### Directory Explanations

**inventories/**: Environment separation (dev/prod)
- Each environment has its own hosts and variables
- Variables cascade: all → groups → hosts
- Inventory files are gitignored (may contain sensitive IPs)

**playbooks/**: Separate playbooks for different use cases
- `workstation_setup.yml` - Development machine configuration
- `server_setup.yml` - Server hardening and setup
- `site.yml` - Master playbook (runs appropriate playbook per host)

**roles/**: Reusable Ansible roles
- Each role is self-contained with tasks, templates, handlers
- Roles can be used across different playbooks

**group_vars/**: Legacy location, now moved to `inventories/*/group_vars/`

## Two-Environment Approach

This repository uses a **development** and **production** environment structure:

### Development Environment
**Purpose**: Testing, local VMs, development machines

**Characteristics**:
- Relaxed security (passwordless sudo, no firewall)
- Default SSH port (22)
- Verbose logging for debugging
- No automatic updates
- SSH password authentication allowed

**Use cases**:
- Local workstation setup
- Testing in VMs (VirtualBox, Proxmox, LXD)
- Learning and experimenting
- Quick iterations

### Production Environment
**Purpose**: Real workstations, production servers

**Characteristics**:
- Strict security (password-required sudo, firewall enabled)
- Custom SSH port (not 22)
- Minimal logging
- Automatic security updates
- SSH key-only authentication
- Encrypted secrets via Ansible Vault

**Use cases**:
- Personal/team laptops
- Production servers
- Internet-facing machines
- Corporate environments

### Switching Environments

```bash
# Development (default in ansible.cfg)
ansible-playbook playbooks/workstation_setup.yml

# Production (explicit)
ansible-playbook playbooks/workstation_setup.yml \
  -i inventories/production/hosts.yml
```

## Available Roles

### Bootstrap

Creates ansible user with SSH key authentication and configurable sudo access.

**Tags**: `bootstrap`

**Variables**:

- `ansible_user_name`: Username for ansible (default: `ansible`)
- `sudo_passwordless_allowed`: Enable passwordless sudo (default: `false` for production)

### Fonts

Installs Nerd Fonts for terminal usage.

**Tags**: `fonts`, `nerdfonts`

**Supported Fonts**: EnvyCodeR (more can be added)

### Hardening

Server security configuration including firewall, fail2ban, and optional IDS/IPS.

**Tags**: `hardening`

**Variables**:

```yaml
ufw_enabled: true
ufw_rules:
  - rule: allow
    port: "{{ ssh_custom_port }}"
    proto: tcp
    comment: "SSH"

fail2ban_enabled: true
fail2ban_bantime: 1w
fail2ban_maxretry: 3
```

### Neovim (nvim)

Installs Neovim with AstroVim configuration and dependencies.

**Tags**: `nvim`

**Includes**: Node.js, lazygit, tree-sitter-cli

### Utilities

Modern CLI tools for enhanced terminal experience.

**Tags**: `utilities`

**Tools**: bat, eza, fd-find, ripgrep, dust, zoxide, tmux

### ZSH

ZSH shell with Oh-My-Zsh and useful plugins.

**Tags**: `zsh`

**Plugins**: autosuggestions, completions, syntax-highlighting, autoupdate

## Testing

This repository includes a comprehensive 3-layer testing approach:

### Layer 1: Unit Testing (Molecule + Docker)
Fast tests for individual roles using Docker containers.

```bash
# Install testing tools (one-time)
make install-molecule

# Test a specific role (~30 seconds)
make test-role ROLE=zsh

# Test all roles
make test-all

# Interactive development
make molecule-create ROLE=zsh    # Create containers
make molecule-converge ROLE=zsh  # Apply role
make molecule-verify ROLE=zsh    # Run tests
make molecule-destroy ROLE=zsh   # Cleanup
```

**Benefits:**
- ⚡ Very fast (30 seconds per role)
- 🔄 Test on Ubuntu and Debian simultaneously
- ✅ Validates idempotency automatically
- 🐳 Uses Docker (lightweight, no VMs needed)

### Quick Start Testing

```bash
# 1. Setup (one-time)
make setup
make install-molecule

# 2. Test before committing
make lint              # Check code quality
make syntax-check      # Validate syntax
make test-role ROLE=zsh  # Test your changes

# 3. Pre-commit checks
make pre-commit        # Runs lint + syntax-check
```

See full testing guide: [docs/TESTING.md](docs/TESTING.md) and [docs/TESTING_QUICKSTART.md](docs/TESTING_QUICKSTART.md)

### Layer 2: Integration Testing (LXD)

✅ **Status: Validated and Working**

System-level testing with full OS containers (~5-10 minutes per scenario).

```bash
# Install LXD (one-time)
sudo snap install lxd
sudo usermod -aG lxd $USER
sudo lxd init --minimal

# Configure network (see docs for details)
# See docs/TESTING_LXD.md for full network setup

# Run integration tests
make lxd-test-workstation  # Test workstation setup
make lxd-test-server        # Test server hardening
make lxd-test-all           # Run all tests

# Clean up
make lxd-clean
```

**Test Results:**
- ✅ Workstation scenario: 64 tasks, 0 failures
- ✅ Roles tested: fonts, utilities, nvim, zsh
- ✅ Full integration validation complete

**Documentation:**
- [LXD Testing Guide](docs/TESTING_LXD.md) - Complete setup and usage
- [Testing Findings](docs/TESTING_FINDINGS.md) - Issues discovered and lessons learned
- [Quick Reference](docs/TESTING_FINDINGS_QUICKREF.md) - Critical issues summary
- [Testing Strategy](docs/TESTING_SUMMARY.md) - Overall testing approach

### Layer 3: Acceptance Testing (Proxmox)

📋 **Status: Planned**

Final validation on production-like VMs in homelab environment.

(Documentation coming soon)

## Security Features

### Production Security Checklist

Before deploying to production servers:

- [ ] Set `sudo_passwordless_allowed: false` in group_vars
- [ ] Configure custom SSH port and update firewall rules
- [ ] Enable UFW firewall
- [ ] Configure fail2ban
- [ ] Disable SSH password authentication
- [ ] Use Ansible Vault for sensitive data
- [ ] Review and test all playbooks in development first

## Configuration Examples

### Development Environment

```yaml
# group_vars/all/common.yml
environment_name: development
sudo_passwordless_allowed: true # Easier for testing
ufw_enabled: false # No firewall restrictions
```

### Production Environment

```yaml
# group_vars/all/common.yml
environment_name: production
sudo_passwordless_allowed: false # Security first
ufw_enabled: true # Firewall required
ssh_password_authentication: no # Keys only
```

## Ansible Vault Usage

```bash
# Create encrypted vault
ansible-vault create group_vars/all/vault.yml

# Edit encrypted vault
ansible-vault edit group_vars/all/vault.yml

# Run playbook with vault
ansible-playbook playbook.yml --ask-vault-pass
```

## Troubleshooting

### Common Issues

**Issue**: "SSH key file not found"
**Solution**: Set `ansible_ssh_public_key_file` variable to correct path

**Issue**: "Locked out after enabling UFW"
**Solution**: Ensure SSH port is allowed before enabling UFW

**Issue**: "Font cache not updating"
**Solution**: Run `fc-cache -fv` manually after font installation

## Requirements

- **Ansible**: >= 2.14
- **Target OS**: Ubuntu 20.04+, Debian 11+
- **Python**: 3.8+ on target systems

## Roadmap

### Planned Features

- [ ] Docker installation and configuration
- [ ] Nextcloud client setup
- [ ] KeePass installation
- [ ] Golang with GVM
- [ ] Multi-OS support (Fedora, Rocky Linux)
- [ ] Molecule testing framework
- [ ] Vagrant/LXD testing setup
- [ ] CI/CD pipeline

### To Be Improved

- [ ] Add checksum verification for all downloads
- [ ] Implement SSH hardening role
- [ ] Add OS hardening with devsec.hardening
- [ ] Create separate playbooks for workstation/server
- [ ] Implement proper inventory structure
- [ ] Add pre-commit hooks
- [ ] ansible-lint integration

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly in development environment
5. Submit a pull request

## License

See [LICENCE](LICENCE) file for details.

## References

- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Ansible Vault Documentation](https://docs.ansible.com/ansible/latest/user_guide/vault.html)
- [DevSec Hardening Framework](https://dev-sec.io/)
- [AstroVim](https://astronvim.com/)
- [Oh My Zsh](https://ohmyz.sh/)

## Support

For issues and questions:

- Check existing issues
- Create new issue with detailed description
- Include Ansible version and target OS information
