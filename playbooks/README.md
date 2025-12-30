# Playbooks

This directory contains all Ansible playbooks for different use cases.

## Available Playbooks

### workstation_setup.yml
Configures development workstations with tools and utilities.

**Installs**:
- Nerd Fonts
- Modern CLI tools (bat, eza, fd, ripgrep, etc.)
- Neovim with AstroVim
- ZSH with Oh-My-Zsh and plugins

**Usage**:
```bash
# Run on localhost
ansible-playbook playbooks/workstation_setup.yml

# Run on remote workstation
ansible-playbook playbooks/workstation_setup.yml -l my-laptop

# Run specific components only
ansible-playbook playbooks/workstation_setup.yml --tags "zsh,nvim"

# Skip certain components
ansible-playbook playbooks/workstation_setup.yml --skip-tags "fonts"
```

### server_setup.yml
Configures and hardens servers.

**Configures**:
- Ansible user with SSH keys
- UFW firewall
- fail2ban intrusion prevention
- SSH hardening
- Automatic security updates

**Usage**:
```bash
# Run on test server
ansible-playbook playbooks/server_setup.yml \
  -i inventories/development/hosts.yml \
  -l test-server \
  --ask-become-pass

# Run on production server
ansible-playbook playbooks/server_setup.yml \
  -i inventories/production/hosts.yml \
  -l web-prod-01 \
  --ask-vault-pass \
  --ask-become-pass

# Run only hardening
ansible-playbook playbooks/server_setup.yml --tags "hardening"
```

### site.yml
Main entry point that runs appropriate playbooks based on host groups.

**Usage**:
```bash
# Run on all hosts (workstations and servers)
ansible-playbook playbooks/site.yml

# Run only on workstations
ansible-playbook playbooks/site.yml --tags "workstation"

# Run only on servers
ansible-playbook playbooks/site.yml --tags "server"
```

## Common Options

### Inventory Selection
```bash
# Use default (development)
ansible-playbook playbooks/workstation_setup.yml

# Specify inventory explicitly
ansible-playbook playbooks/workstation_setup.yml \
  -i inventories/production/hosts.yml
```

### Host Limiting
```bash
# Run on specific host
ansible-playbook playbooks/workstation_setup.yml -l localhost

# Run on group
ansible-playbook playbooks/server_setup.yml -l servers

# Run on multiple hosts
ansible-playbook playbooks/server_setup.yml -l "web-01,web-02"
```

### Privilege Escalation
```bash
# Prompt for sudo password
ansible-playbook playbooks/server_setup.yml --ask-become-pass

# Use specific sudo user
ansible-playbook playbooks/server_setup.yml --become-user=root
```

### Vault Operations
```bash
# Prompt for vault password
ansible-playbook playbooks/server_setup.yml --ask-vault-pass

# Use vault password file
ansible-playbook playbooks/server_setup.yml \
  --vault-password-file ~/.vault_pass

# Multiple vaults
ansible-playbook playbooks/server_setup.yml \
  --vault-id dev@prompt \
  --vault-id prod@~/.vault_pass_prod
```

### Testing and Validation
```bash
# Syntax check
ansible-playbook playbooks/workstation_setup.yml --syntax-check

# Dry run (check mode)
ansible-playbook playbooks/workstation_setup.yml --check

# Dry run with diff
ansible-playbook playbooks/workstation_setup.yml --check --diff

# List tasks
ansible-playbook playbooks/workstation_setup.yml --list-tasks

# List hosts
ansible-playbook playbooks/workstation_setup.yml --list-hosts
```

## Tags

### Workstation Tags
- `fonts` - Font installation
- `nerdfonts` - Nerd Fonts specifically
- `utilities` - CLI tools
- `cli-tools` - Alternative for utilities
- `nvim` - Neovim
- `editor` - Alternative for nvim
- `astronvim` - AstroVim configuration
- `zsh` - ZSH shell
- `shell` - Alternative for zsh

### Server Tags
- `bootstrap` - Ansible user setup
- `users` - Alternative for bootstrap
- `hardening` - Security hardening
- `security` - Alternative for hardening

### Usage Examples
```bash
# Install only ZSH and Neovim
ansible-playbook playbooks/workstation_setup.yml --tags "zsh,nvim"

# Run everything except fonts
ansible-playbook playbooks/workstation_setup.yml --skip-tags "fonts"

# Only security hardening
ansible-playbook playbooks/server_setup.yml --tags "hardening"
```

## Variables

### Workstation Variables
Control what gets installed:

```yaml
# In group_vars or host_vars
install_fonts: true
install_utilities: true
install_astronvim: true
install_zsh: true
```

### Server Variables
Control security settings:

```yaml
# In group_vars or host_vars
apply_hardening: true
ufw_enabled: true
fail2ban_enabled: true
sudo_passwordless_allowed: false
ssh_custom_port: 65522
```

## Best Practices

1. **Test First**: Always test in development environment
2. **Use Check Mode**: Run with `--check --diff` before actual run
3. **Limit Hosts**: Use `-l` to target specific hosts
4. **Tag Strategically**: Use tags for incremental updates
5. **Document Changes**: Keep notes of what you run and when
6. **Backup First**: Take snapshots before major changes
7. **Review Output**: Check for errors and warnings

## Examples

### Example 1: Fresh Workstation Setup
```bash
# Full setup on local machine
ansible-playbook playbooks/workstation_setup.yml \
  -l localhost \
  --ask-become-pass
```

### Example 2: Update Tools Only
```bash
# Update CLI utilities without touching other components
ansible-playbook playbooks/workstation_setup.yml \
  --tags "utilities" \
  -l my-laptop
```

### Example 3: Production Server Deployment
```bash
# Full server setup with all security
ansible-playbook playbooks/server_setup.yml \
  -i inventories/production/hosts.yml \
  -l web-prod-01 \
  --ask-vault-pass \
  --ask-become-pass \
  --check --diff  # Test first!

# If check looks good, run for real
ansible-playbook playbooks/server_setup.yml \
  -i inventories/production/hosts.yml \
  -l web-prod-01 \
  --ask-vault-pass \
  --ask-become-pass
```

### Example 4: Firewall Update Only
```bash
# Update firewall rules without running full hardening
ansible-playbook playbooks/server_setup.yml \
  --tags "hardening" \
  -l web-servers
```

## Troubleshooting

### Connection Issues
```bash
# Test connectivity
ansible all -m ping -i inventories/development/hosts.yml

# Verbose output
ansible-playbook playbooks/workstation_setup.yml -vvv
```

### Permission Issues
```bash
# Use different user
ansible-playbook playbooks/server_setup.yml -u root

# Prompt for password
ansible-playbook playbooks/server_setup.yml \
  --ask-become-pass \
  --ask-pass
```

### Validation
```bash
# Check what would change
ansible-playbook playbooks/workstation_setup.yml --check --diff

# List all tasks that would run
ansible-playbook playbooks/workstation_setup.yml --list-tasks

# See which hosts would be affected
ansible-playbook playbooks/server_setup.yml --list-hosts
```
