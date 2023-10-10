# How-To Recipes

Practical guides for common ansible-pack use cases.

## Table of Contents

- [Use Cases](#use-cases)
  - [1. Setup Development Workstation (Local)](#1-setup-development-workstation-local)
  - [2. Setup Remote VPS (Production Server)](#2-setup-remote-vps-production-server)
  - [3. Setup Work Laptop (Custom Tools)](#3-setup-work-laptop-custom-tools)
  - [4. Setup Ansible Development Environment](#4-setup-ansible-development-environment)
  - [5. Enable/Disable Specific Tools](#5-enabledisable-specific-tools)
  - [6. Quick Validation Testing](#6-quick-validation-testing)
- [Configuration Patterns](#configuration-patterns)
- [Troubleshooting](#troubleshooting)

---

## Use Cases

### 1. Setup Development Workstation (Local)

**Goal**: Configure your local machine with development tools, terminal utilities, and custom shell.

**Steps:**

1. **Install Ansible** (if not already installed):
   ```bash
   sudo apt update
   sudo apt install ansible
   ```

2. **Clone repository**:
   ```bash
   cd ~/repos
   git clone <your-repo-url> ansible-pack
   cd ansible-pack
   ```

3. **Install dependencies**:
   ```bash
   ansible-galaxy collection install -r meta/requirements.yml
   ansible-galaxy role install -r meta/requirements.yml
   ```

4. **Copy inventory** (localhost is already configured):
   ```bash
   cp inventories/development/hosts.yml.example inventories/development/hosts.yml
   ```

5. **Run workstation setup**:
   ```bash
   ansible-playbook playbooks/workstation_setup.yml --ask-become-pass
   ```

6. **What gets installed**:
   - ✅ Nerd Fonts (EnvyCodeR)
   - ✅ Modern CLI tools (bat, eza, fd, ripgrep, dust, zoxide, tmux, lazygit)
   - ✅ Neovim with AstroVim
   - ✅ ZSH with Oh-My-Zsh + plugins
   - ✅ No hardening (convenience over security for local dev)

7. **Restart your shell**:
   ```bash
   exec zsh
   ```

---

### 2. Setup Remote VPS (Production Server)

**Goal**: Harden and configure an internet-facing VPS with security-first approach.

**Steps:**

1. **Prepare SSH key** (on your local machine):
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/ansible_key -N ""

   # Copy to VPS
   ssh-copy-id -i ~/.ssh/ansible_key.pub root@your-vps-ip
   ```

2. **Create inventory**:
   ```bash
   cp inventories/production/hosts.yml.example inventories/production/hosts.yml
   vim inventories/production/hosts.yml
   ```

   Add your VPS:
   ```yaml
   all:
     children:
       servers:
         hosts:
           my-vps:
             ansible_host: 203.0.113.10
             ssh_custom_port: 65522  # Change after first run
   ```

3. **Review security settings**:
   ```bash
   vim inventories/production/group_vars/servers/main.yml
   ```

   Ensure production settings:
   ```yaml
   apply_hardening: true
   ufw_enabled: true
   fail2ban_enabled: true
   ssh_password_authentication: no
   sudo_passwordless_allowed: false
   ```

4. **First run** (as root, standard SSH port):
   ```bash
   ansible-playbook playbooks/server_setup.yml \
     -i inventories/production/hosts.yml \
     -l my-vps \
     -u root \
     --ask-become-pass
   ```

5. **Update SSH port** (after first successful run):
   - Edit `inventories/production/hosts.yml` and set `ssh_custom_port: 65522`
   - Ensure UFW allows the custom port before enabling

6. **Subsequent runs** (with ansible user):
   ```bash
   ansible-playbook playbooks/server_setup.yml \
     -i inventories/production/hosts.yml \
     -l my-vps \
     -u ansible \
     --ask-become-pass
   ```

**What gets configured**:
- ✅ Dedicated ansible user with sudo access
- ✅ UFW firewall with only necessary ports open
- ✅ fail2ban intrusion prevention
- ✅ SSH hardening (custom port, key-only auth)
- ✅ OS hardening (sysctl, permissions)
- ✅ Automatic security updates
- ❌ No CLI tools or dev environment (minimal install)

---

### 3. Setup Work Laptop (Custom Tools)

**Goal**: Configure work machine with company-specific tools (Terragrunt, kubectl, AWS CLI).

**Steps:**

1. **Create host-specific configuration**:
   ```bash
   mkdir -p inventories/development/host_vars/my-work-laptop
   vim inventories/development/host_vars/my-work-laptop/main.yml
   ```

   Add:
   ```yaml
   ---
   # Enable devops tools
   install_docker: true
   install_terragrunt: true
   install_tenv: true  # Terraform version manager

   # Enable cloud tools
   install_kubectl: true
   install_aws_cli: true

   # Customize utilities (disable some, keep others)
   install_utilities: true
   utilities_install_lazygit: false  # Don't need this at work
   ```

2. **Add to inventory**:
   ```bash
   vim inventories/development/hosts.yml
   ```

   ```yaml
   all:
     children:
       workstations:
         hosts:
           my-work-laptop:
             ansible_host: 192.168.1.100
             # or ansible_connection: local if running locally
   ```

3. **Run playbook**:
   ```bash
   ansible-playbook playbooks/workstation_setup.yml \
     -l my-work-laptop \
     --ask-become-pass
   ```

4. **Verify installations**:
   ```bash
   docker --version
   terragrunt --version
   tenv --version
   kubectl version --client
   aws --version
   ```

---

### 4. Setup Ansible Development Environment

**Goal**: Minimal setup for testing and developing ansible-pack itself.

**Steps:**

1. **Create dedicated playbook** (already planned in roadmap):
   ```bash
   # This will be created in Phase 4
   ansible-playbook playbooks/ansible_dev.yml --ask-become-pass
   ```

2. **Or use tags** to install only what you need:
   ```bash
   ansible-playbook playbooks/workstation_setup.yml \
     --tags "utilities,zsh" \
     --ask-become-pass
   ```

3. **Install Molecule for testing**:
   ```bash
   make install-molecule
   ```

4. **Test a role**:
   ```bash
   make test-role ROLE=zsh
   ```

---

### 5. Enable/Disable Specific Tools

**Goal**: Fine-grained control over what gets installed.

#### A. Disable all utilities except tmux

**Edit**: `inventories/development/group_vars/workstations/main.yml`

```yaml
# Disable utilities role entirely
install_utilities: false

# But enable just tmux
utilities_install_tmux: true
```

#### B. Install everything except lazygit

```yaml
# Enable utilities role
install_utilities: true

# Disable specific tool
utilities_install_lazygit: false
```

#### C. Work machine: Add Terragrunt and kubectl

**Create**: `inventories/development/host_vars/work-machine/main.yml`

```yaml
---
# Inherit workstation defaults, but add:
install_docker: true
install_terragrunt: true
install_kubectl: true
```

#### D. Selective role installation with tags

```bash
# Only install zsh and fonts
ansible-playbook playbooks/workstation_setup.yml \
  --tags "zsh,fonts" \
  --ask-become-pass

# Install everything except nvim
ansible-playbook playbooks/workstation_setup.yml \
  --skip-tags "nvim" \
  --ask-become-pass
```

---

### 6. Quick Validation Testing

**Goal**: Verify installations work correctly without manual testing.

**Current approach** (manual):

```bash
# Test CLI tools
bat --version
eza --version
fd --version
rg --version

# Test ZSH
zsh --version
which oh-my-zsh

# Test Neovim
nvim --version
```

**Future validation playbook** (coming in Phase 5):

```bash
ansible-playbook playbooks/validate.yml
```

This will run automated checks for all installed tools.

---

## Configuration Patterns

### Minimal Installation (Fast, Essential Only)

**Use case**: Quick setup, slow connection, minimal dependencies

**Configuration**:
```yaml
# inventories/development/group_vars/workstations/main.yml
install_utilities: false
utilities_install_tmux: true  # Only tmux

install_zsh: true
install_astronvim: false  # Skip heavy Neovim setup
install_fonts: false
```

**What you get**:
- ZSH shell with Oh-My-Zsh
- tmux terminal multiplexer
- ~5-minute install time

---

### Full-Featured Workstation (Everything)

**Use case**: Personal laptop, homelab workstation, full dev environment

**Configuration**:
```yaml
# inventories/development/group_vars/workstations/main.yml
install_utilities: true
install_zsh: true
install_astronvim: true
install_fonts: true
install_docker: true
```

**What you get**:
- All CLI tools
- ZSH with full plugin suite
- Neovim with AstroVim
- Nerd Fonts
- Docker
- ~15-20 minute install time

---

### Hardened Server (Production)

**Use case**: VPS, production server, internet-facing

**Configuration**:
```yaml
# inventories/production/group_vars/servers/main.yml
install_utilities: false  # No fancy tools on servers
install_zsh: false
install_astronvim: false
install_fonts: false

apply_hardening: true
ufw_enabled: true
fail2ban_enabled: true
ssh_custom_port: 65522
ssh_password_authentication: no
sudo_passwordless_allowed: false
```

**What you get**:
- Minimal packages
- UFW firewall configured
- fail2ban active
- SSH hardened
- Automatic security updates
- ~10 minute install time

---

### VPS with Monitoring (Future)

**Use case**: Production VPS with observability

**Configuration** (when monitoring role is added):
```yaml
# inventories/production/group_vars/servers/main.yml
apply_hardening: true
monitoring_enabled: true  # Coming in Phase 4

monitoring_install_node_exporter: true
monitoring_install_prometheus: false  # Only if running Prometheus server
monitoring_install_grafana: false
```

---

## Troubleshooting

### SSH Connection Issues

**Problem**: `Permission denied (publickey)`

**Solution**:
```bash
# Verify SSH key
ssh-keygen -l -f ~/.ssh/ansible_key.pub

# Copy key to target
ssh-copy-id -i ~/.ssh/ansible_key.pub user@host

# Test connection
ssh -i ~/.ssh/ansible_key user@host

# Update inventory with correct key path
vim inventories/development/group_vars/all/common.yml
# Set: ansible_ssh_public_key_file: "~/.ssh/ansible_key.pub"
```

---

### Firewall Lockout

**Problem**: Enabled UFW and now can't SSH

**Prevention**:
```yaml
# Always ensure SSH port is allowed before enabling UFW
ufw_rules:
  - rule: allow
    port: "{{ ssh_custom_port }}"
    proto: tcp
    comment: "SSH"
```

**Recovery**:
- If you have console access (VPS control panel), disable UFW: `sudo ufw disable`
- Or add rule: `sudo ufw allow 22/tcp`

---

### Font Cache Not Updating

**Problem**: Installed Nerd Fonts but not showing in terminal

**Solution**:
```bash
# Rebuild font cache
fc-cache -fv

# Verify fonts installed
fc-list | grep "Envy"

# Restart terminal application
```

---

### Neovim / AstroVim Issues

**Problem**: Neovim opens with errors

**Solution**:
```bash
# Check Neovim version
nvim --version
# Should be >= 0.9

# Check Node.js (required by AstroVim)
node --version
npm --version

# Reinstall AstroVim
rm -rf ~/.config/nvim
rm -rf ~/.local/share/nvim
rm -rf ~/.local/state/nvim
rm -rf ~/.cache/nvim

# Re-run playbook
ansible-playbook playbooks/workstation_setup.yml \
  --tags "nvim" \
  --ask-become-pass
```

---

### ZSH Plugins Not Loading

**Problem**: ZSH installed but plugins (autosuggestions, syntax-highlighting) not working

**Solution**:
```bash
# Check plugins installed
ls -la ~/.oh-my-zsh/custom/plugins/

# Should see:
# - zsh-autosuggestions
# - zsh-completions
# - zsh-syntax-highlighting

# Check .zshrc configuration
cat ~/.zshrc | grep plugins

# Reload configuration
source ~/.zshrc

# Or restart shell
exec zsh
```

---

### Ansible Task Fails with "Module not found"

**Problem**: `ERROR! couldn't resolve module/action 'community.general.apt_key'`

**Solution**:
```bash
# Install required collections
ansible-galaxy collection install -r meta/requirements.yml

# Verify collections installed
ansible-galaxy collection list

# Should show:
# - community.general
# - ansible.posix
# - devsec.hardening (if using hardening role)
```

---

### Role Skipped Unexpectedly

**Problem**: Running playbook but role doesn't execute

**Debug**:
```bash
# Check with verbose output
ansible-playbook playbooks/workstation_setup.yml -vv --ask-become-pass

# Check role condition
vim inventories/development/group_vars/workstations/main.yml

# Look for:
install_utilities: false  # Should be true if you want utilities
install_zsh: false         # Should be true if you want zsh
```

**Solution**: Ensure role flags are enabled in your inventory group_vars or host_vars.

---

### Check Mode Fails but Normal Mode Works

**Problem**: `--check` mode reports errors but actual run succeeds

**Explanation**: This is normal for tasks that:
- Download files (can't verify URL without downloading)
- Check if command exists (command not installed yet)
- Create directories (parent doesn't exist yet)

**Solution**: For initial setup, run without `--check`. For subsequent runs, `--check` will be more accurate.

---

## Need More Help?

- Check [TESTING.md](TESTING.md) for testing and validation procedures
- Check [REFERENCE.md](REFERENCE.md) for complete variable documentation
- Check [README.md](../README.md) for quick start guide
- Open an issue on the repository with detailed error messages
