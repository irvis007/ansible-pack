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

1. **Configure variables** in `group_vars/all/common.yml`:

```yaml
ansible_ssh_public_key_file: "{{ lookup('env', 'HOME') }}/.ssh/ansible_key.pub"
ssh_custom_port: 65522
```

2. **For production** (optional), create encrypted vault:

```bash
cp group_vars/all/vault.yml.example group_vars/all/vault.yml
ansible-vault encrypt group_vars/all/vault.yml
```

### Run Playbooks

```bash
# Setup workstation (run on localhost or remote)
ansible-playbook playbook.yml -i inventory.ini --ask-become-pass

# Run specific role only
ansible-playbook playbook.yml --tags "docker" -i inventory.ini --ask-become-pass

# Run server hardening
ansible-playbook playbook.yml --tags "hardening" -i inventory.ini --ask-become-pass
```

## Repository Structure

```
ansible-pack/
├── group_vars/
│   └── all/
│       ├── common.yml           # Common variables
│       └── vault.yml.example    # Example vault file
├── roles/
│   ├── bootstrap/               # Bootstrap ansible user
│   ├── fonts/                   # Install Nerd Fonts
│   ├── hardening/               # Server security hardening
│   ├── nvim/                    # Neovim + AstroVim setup
│   ├── utilities/               # CLI tools installation
│   └── zsh/                     # ZSH + Oh-My-Zsh setup
├── meta/
│   └── requirements.yml         # External collections/roles
├── playbook.yml                 # Main playbook
├── inventory.ini                # Inventory file (gitignored)
└── ansible.cfg                  # Ansible configuration
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
