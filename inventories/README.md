# Inventories

This directory contains environment-specific inventories and configurations.

## Structure

```
inventories/
├── development/
│   ├── hosts.yml              # Development hosts (gitignored)
│   ├── hosts.yml.example      # Example template
│   └── group_vars/
│       ├── all/
│       │   ├── common.yml     # Common variables for all dev hosts
│       │   └── vault.yml.example
│       ├── workstations/
│       │   └── main.yml       # Development workstation config
│       └── servers/
│           └── main.yml       # Development server config
│
└── production/
    ├── hosts.yml              # Production hosts (gitignored)
    ├── hosts.yml.example      # Example template
    └── group_vars/
        ├── all/
        │   ├── common.yml     # Common variables for all prod hosts
        │   └── vault.yml.example
        ├── workstations/
        │   └── main.yml       # Production workstation config
        └── servers/
            └── main.yml       # Production server config
```

## Setup

### 1. Create Your Inventory Files

```bash
# Development
cp inventories/development/hosts.yml.example inventories/development/hosts.yml
# Edit and add your hosts
vim inventories/development/hosts.yml

# Production
cp inventories/production/hosts.yml.example inventories/production/hosts.yml
# Edit and add your hosts
vim inventories/production/hosts.yml
```

### 2. Configure Secrets (Optional)

```bash
# Create vault file
cp inventories/production/group_vars/all/vault.yml.example \
   inventories/production/group_vars/all/vault.yml

# Edit and add secrets
ansible-vault create inventories/production/group_vars/all/vault.yml

# Or encrypt existing file
ansible-vault encrypt inventories/production/group_vars/all/vault.yml
```

## Environments

### Development Environment

**Purpose**: Local testing, VMs, development machines

**Characteristics**:
- Relaxed security (passwordless sudo, firewall disabled)
- Verbose logging
- No automatic updates
- SSH password authentication allowed

**Usage**:
```bash
# Default environment (configured in ansible.cfg)
ansible-playbook playbooks/workstation_setup.yml

# Or explicitly specify
ansible-playbook playbooks/workstation_setup.yml -i inventories/development/hosts.yml
```

### Production Environment

**Purpose**: Real workstations, production servers

**Characteristics**:
- Strict security (password-required sudo, firewall enabled)
- Minimal logging
- Automatic updates enabled
- SSH key-only authentication

**Usage**:
```bash
# Explicitly specify production inventory
ansible-playbook playbooks/server_setup.yml \
  -i inventories/production/hosts.yml \
  --ask-vault-pass \
  --ask-become-pass
```

## Host Groups

### Workstations
- Laptops, desktops, development machines
- Installs development tools (Docker, AstroVim, ZSH, etc.)
- Relaxed security posture

### Servers
- Production servers, test servers
- Minimal software installation
- Strict security hardening
- Firewall, fail2ban, automatic updates

## Variables Priority

Ansible variable precedence (highest to lowest):

1. `host_vars/<hostname>/` - Host-specific variables
2. `group_vars/<groupname>/` - Group-specific variables (workstations, servers)
3. `group_vars/all/` - Common variables for all hosts
4. Role defaults - Defined in `roles/*/defaults/main.yml`

## Examples

### Example 1: Local Workstation Setup

```yaml
# inventories/development/hosts.yml
all:
  children:
    workstations:
      hosts:
        localhost:
          ansible_connection: local
```

```bash
# Run setup
ansible-playbook playbooks/workstation_setup.yml
```

### Example 2: Remote Server Setup

```yaml
# inventories/production/hosts.yml
all:
  children:
    servers:
      hosts:
        web-prod-01:
          ansible_host: 10.0.2.10
          ansible_user: ansible
```

```bash
# Run setup
ansible-playbook playbooks/server_setup.yml \
  -i inventories/production/hosts.yml \
  --ask-become-pass
```

### Example 3: Multiple Environments

```bash
# Test on development
ansible-playbook playbooks/server_setup.yml \
  -i inventories/development/hosts.yml \
  -l test-server

# Deploy to production
ansible-playbook playbooks/server_setup.yml \
  -i inventories/production/hosts.yml \
  -l web-prod-01 \
  --ask-vault-pass \
  --ask-become-pass
```

## Tips

1. **Never commit** actual `hosts.yml` files with real IPs/hostnames
2. **Always use** Ansible Vault for sensitive data in production
3. **Test first** in development environment before production
4. **Use tags** to run specific parts of playbooks
5. **Check syntax** before running: `ansible-playbook playbook.yml --syntax-check`
6. **Dry run** with: `ansible-playbook playbook.yml --check --diff`

## Security Notes

- Inventory files are gitignored by default (may contain sensitive IPs)
- Vault files are gitignored (contain secrets)
- Use `vault.yml.example` as templates, never commit actual vault files
- Production should always use encrypted vaults with strong passwords
- Rotate vault passwords regularly
