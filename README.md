# Ansible Pack - Workstation & Server Automation

Automated setup for development workstations and production servers on Ubuntu/Debian systems. Infrastructure-as-Code approach with comprehensive testing and security hardening.

## Features

**Workstations**: Neovim + AstroVim, ZSH + Oh-My-Zsh, modern CLI tools (bat, eza, fd, ripgrep, dust, zoxide, tmux), Nerd Fonts, optional DevOps tools (Docker, Terragrunt, kubectl)

**Servers**: UFW firewall, fail2ban, SSH hardening, OS hardening, automatic security updates, optional IDS/IPS (Suricata)

**Testing**: 3-layer pyramid (Molecule/Docker → LXD → Proxmox) for fast development and production-like validation

---

## Quick Start

### 1. Install Ansible

```bash
sudo apt update && sudo apt install ansible
```

### 2. Clone & Install Dependencies

```bash
git clone <your-repo-url> ansible-pack
cd ansible-pack
ansible-galaxy collection install -r meta/requirements.yml
ansible-galaxy role install -r meta/requirements.yml
```

### 3. Configure Inventory

```bash
# Copy example inventory
cp inventories/hosts.yml.example inventories/hosts.yml

# Edit to add your hosts
vim inventories/hosts.yml
```

**Example hosts.yml:**

```yaml
all:
  children:
    workstations:
      hosts:
        localhost:
          ansible_connection: local
    servers:
      hosts:
        my-homelab-server:
          ansible_host: 192.168.1.20
    vps:
      hosts:
        my-vps:
          ansible_host: 203.0.113.10
          ssh_custom_port: 65522
```

### 4. Run Playbook

```bash
# Setup local workstation
ansible-playbook playbooks/workstation_setup.yml --ask-become-pass

# Setup remote server
ansible-playbook playbooks/server_setup.yml -l my-homelab-server --ask-become-pass

# Setup VPS (production)
ansible-playbook playbooks/server_setup.yml -l my-vps --ask-become-pass

# Selective installation with tags
ansible-playbook playbooks/workstation_setup.yml --tags "zsh,nvim" --ask-become-pass
```

---

## Directory Structure

```
ansible-pack/
├── playbooks/              # Main playbooks (workstation, server, site)
├── roles/                  # Reusable roles (bootstrap, fonts, hardening, nvim, utilities, zsh)
├── inventories/            # Single inventory with host groups (workstations, servers, vps)
│   ├── hosts.yml          # Your hosts (gitignored)
│   └── group_vars/        # Group-specific configuration
├── docs/                   # Documentation
│   ├── HOW-TO.md         # Practical recipes and use cases
│   ├── REFERENCE.md      # Complete variable reference
│   ├── TESTING.md        # Testing guide (3 layers)
│   └── ARCHITECTURE.md   # Design decisions
├── tests/                  # Testing frameworks (LXD, Proxmox)
└── Makefile               # Automation commands
```

---

## Host Groups

ansible-pack organizes machines by **purpose**, not environment:

**workstations**: Dev machines, personal laptops

- All tools installed, minimal hardening, convenience over security
- Examples: localhost, my-laptop, work-machine

**servers**: Homelab internal servers

- Selected tools, moderate hardening, balanced security
- Examples: homelab-server-01, homelab-nas

**vps**: Internet-facing production servers

- Minimal tools, maximum hardening, security-first
- Examples: vps-prod-01, vps-prod-02

Configure each group in `inventories/group_vars/<group>/main.yml`

---

## Common Commands

```bash
# Testing
make test-role ROLE=zsh          # Unit test (Molecule + Docker)
make lxd-test-workstation        # Integration test (LXD)
make lint                         # Code quality checks

# Local setup
make workstation-local           # Quick local workstation setup

# Dry run
ansible-playbook playbooks/workstation_setup.yml --check

# Syntax validation
make syntax-check
```

---

## Configuration Examples

### Minimal Workstation (Fast Setup)

```yaml
# inventories/group_vars/workstations/main.yml
install_utilities: false
utilities_install_tmux: true # Only tmux
install_zsh: true
install_astronvim: false # Skip heavy Neovim setup
install_fonts: false
```

### Full-Featured Workstation

```yaml
# inventories/group_vars/workstations/main.yml
install_utilities: true
install_zsh: true
install_astronvim: true
install_fonts: true
devops_tools_enabled: true
cloud_tools_enabled: true
```

### Hardened VPS

```yaml
# inventories/group_vars/vps/main.yml
install_utilities: false # No fancy tools on production
apply_hardening: true
hardening_enable_fail2ban: true
hardening_enable_ufw: true
hardening_enable_ssh_hardening: true
ssh_custom_port: 65522
ssh_password_authentication: no
```

---

## Documentation

- **[HOW-TO.md](docs/HOW-TO.md)** - Practical recipes for common use cases (setup workstation, VPS, work laptop, enable/disable tools)
- **[TESTING.md](docs/TESTING.md)** - Complete testing guide (Molecule, LXD, Proxmox)
- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Design decisions and conventions
- **[REFERENCE.md](docs/REFERENCE.md)** - Complete variable reference _(coming soon)_
- **[ROADMAP.md](ROADMAP.md)** - Planned features and priorities

---

## Available Roles

| Role          | Purpose                                                      | Tags                     |
| ------------- | ------------------------------------------------------------ | ------------------------ |
| **bootstrap** | Create ansible user with SSH key auth                        | `bootstrap`              |
| **fonts**     | Install Nerd Fonts (EnvyCodeR)                               | `fonts`, `nerdfonts`     |
| **hardening** | Security hardening (UFW, fail2ban, SSH/OS hardening)         | `hardening`, `security`  |
| **nvim**      | Neovim + AstroVim + dependencies                             | `nvim`, `editor`         |
| **utilities** | Modern CLI tools (bat, eza, fd, ripgrep, dust, zoxide, tmux) | `utilities`, `cli-tools` |
| **zsh**       | ZSH + Oh-My-Zsh + plugins + Powerlevel10k                    | `zsh`, `shell`           |

---

## Requirements

- **Ansible**: >= 2.14
- **Target OS**: Ubuntu 20.04+, Debian 11+
- **Python**: 3.8+ on target systems
- **SSH**: Key-based authentication recommended for remote hosts

---

## Security

**Production Checklist:**

- [ ] Configure custom SSH port and update firewall rules
- [ ] Enable UFW firewall (`ufw_enabled: true`)
- [ ] Enable fail2ban (`hardening_enable_fail2ban: true`)
- [ ] Disable SSH password auth (`ssh_password_authentication: no`)
- [ ] Require password for sudo (`sudo_passwordless_allowed: false`)
- [ ] Use Ansible Vault for secrets
- [ ] Test all playbooks in development/testing environment first

See [HOW-TO.md](docs/HOW-TO.md) for VPS setup guide with security best practices.

---

## Troubleshooting

**SSH Connection Issues**: Verify SSH key is copied to target host

```bash
ssh-copy-id -i ~/.ssh/ansible_key.pub user@host
```

**Firewall Lockout**: Always allow SSH port before enabling UFW

```yaml
ufw_rules:
  - rule: allow
    port: "{{ ssh_custom_port }}"
    proto: tcp
```

**Font Cache Not Updating**: Rebuild font cache manually

```bash
fc-cache -fv
```

**Module Not Found**: Install required Ansible collections

```bash
ansible-galaxy collection install -r meta/requirements.yml
```

See [HOW-TO.md](docs/HOW-TO.md) for detailed troubleshooting guides.

---

## License

MIT License - See [LICENCE](LICENCE) file for details.

## Support

- Check [HOW-TO.md](docs/HOW-TO.md) for practical guides
- Check [TESTING.md](docs/TESTING.md) for testing procedures
- Review [ROADMAP.md](ROADMAP.md) for planned features
- Open an issue with detailed error messages and Ansible version

---

_Ansible Pack - Infrastructure as Code for Homelab & Production_
