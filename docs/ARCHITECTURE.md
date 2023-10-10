# Architecture & Design Decisions

This document explains the design philosophy, architectural patterns, and key decisions behind ansible-pack.

## Table of Contents

- [Philosophy](#philosophy)
- [Variable Naming Convention](#variable-naming-convention)
- [Role Structure](#role-structure)
- [Inventory Organization](#inventory-organization)
- [Backward Compatibility Strategy](#backward-compatibility-strategy)
- [Testing Strategy](#testing-strategy)
- [Security Approach](#security-approach)

---

## Philosophy

### Infrastructure as Code
- **Explicit over implicit**: Variables are clearly named and defaults are documented
- **Idempotent operations**: All tasks can be run multiple times safely
- **No hidden state**: Configuration is version-controlled, not scattered across systems

### User-Centric Design
- **Minimal by default**: Base installation is lean; users opt-in to features
- **Gradual adoption**: Users can start simple and add complexity as needed
- **Clear escape hatches**: Tags, host_vars, and conditionals provide flexibility

### Maintainability
- **Single responsibility**: Each role does one thing well
- **DRY (Don't Repeat Yourself)**: Common patterns extracted into reusable components
- **Documentation inline**: Code comments explain "why", not just "what"

---

## Variable Naming Convention

### Pattern: `<role>_<feature>_<attribute>`

This three-tier naming structure provides clarity and avoids naming collisions.

**Examples:**
```yaml
# Role: utilities
# Feature: install
# Attribute: bat (the tool name)
utilities_install_bat: true

# Role: hardening
# Feature: enable
# Attribute: fail2ban
hardening_enable_fail2ban: true

# Role: devops-tools
# Feature: install
# Attribute: docker
devops_tools_install_docker: true

# Role: cloud-tools
# Feature: install
# Attribute: kubectl
cloud_tools_install_kubectl: true
```

### Legacy Patterns (Maintained for Backward Compatibility)

**Role-level toggles:**
```yaml
install_utilities: true  # Enable entire utilities role
install_zsh: true        # Enable entire zsh role
install_docker: true     # Enable Docker (maps to devops_tools_install_docker)
```

These exist for backward compatibility and convenience. They map to the newer granular variables internally.

### Variable Types

1. **Boolean flags** (true/false):
   ```yaml
   utilities_install_bat: true
   ```

2. **String values** (versions, paths):
   ```yaml
   utilities_dust_version: "v1.0.0"
   cloud_tools_kubectl_version: "latest"
   ```

3. **Lists** (collections):
   ```yaml
   devops_tools_docker_users: ["user1", "user2"]
   ufw_rules:
     - rule: allow
       port: 22
   ```

4. **Computed values** (derived from other variables):
   ```yaml
   utilities_enabled: "{{ install_utilities | default(true) }}"
   fail2ban_enabled: "{{ hardening_enable_fail2ban and hardening_enabled }}"
   ```

---

## Role Structure

### Standard Role Layout

```
roles/example-role/
├── defaults/
│   └── main.yml          # Default variable values
├── tasks/
│   ├── main.yml          # Orchestrator (includes other task files)
│   ├── feature-a.yml     # Feature-specific tasks
│   └── feature-b.yml
├── templates/
│   └── config.j2         # Jinja2 templates
├── files/
│   └── static-file.txt   # Static files to copy
├── vars/
│   └── main.yml          # Internal variables (not meant to be overridden)
├── handlers/
│   └── main.yml          # Event handlers (restart services, etc.)
├── meta/
│   └── main.yml          # Role dependencies and metadata
└── tests/
    └── validation.yml    # Post-installation validation tasks
```

### Orchestrator Pattern

**roles/utilities/tasks/main.yml** (orchestrator):
```yaml
---
- name: Include user-specific variables
  include_vars: vars.yml
  tags: utilities

- name: Include bat installation
  include_tasks: bat.yml
  when: utilities_install_bat | bool
  tags: ['utilities', 'bat']

- name: Include eza installation
  include_tasks: eza.yml
  when: utilities_install_eza | bool
  tags: ['utilities', 'eza']
```

**Benefits:**
- Main file stays clean and readable
- Features can be toggled via variables
- Tags enable selective execution
- Easy to add new features (new task file + include statement)

### Task File Organization

**Feature-specific tasks** (roles/utilities/tasks/bat.yml):
```yaml
---
- name: Install bat
  become: true
  ansible.builtin.package:
    state: present
    name: bat

- name: Create bat to batcat link on Debian
  become: true
  ansible.builtin.file:
    src: "/usr/bin/batcat"
    dest: "/usr/bin/bat"
    state: link
  when: ansible_os_family == 'Debian'
```

**Characteristics:**
- Self-contained (can be understood without context)
- Conditional logic at task level (not file level)
- OS-specific handling where needed

---

## Inventory Organization

### Host Groups by Purpose

ansible-pack uses a single inventory with **host groups organized by purpose**, not environment.

**Structure:**
```
inventories/
├── hosts.yml              # Single inventory file (gitignored)
├── hosts.yml.example      # Template with examples
└── group_vars/
    ├── all/
    │   └── common.yml     # Shared configuration
    ├── workstations/
    │   └── main.yml       # Dev machines, personal laptops
    ├── servers/
    │   └── main.yml       # Homelab internal servers
    └── vps/
        └── main.yml       # Internet-facing production servers
```

### Host Groups

**Workstations**: Development machines and personal laptops
- All tools installed (utilities, zsh, nvim, fonts)
- Minimal hardening (convenience over security)
- Optional devops/cloud tools per machine
- Examples: localhost, my-laptop, work-machine

**Servers**: Homelab internal servers
- Selected tools only (Docker, minimal utilities)
- Moderate hardening (firewall, fail2ban, OS hardening)
- Internal network (standard SSH port OK)
- Examples: homelab-server-01, homelab-nas

**VPS**: Internet-facing production servers
- Minimal tools (security-first)
- Maximum hardening (all security features enabled)
- Custom SSH port, key-only auth
- Examples: vps-prod-01, vps-prod-02

### Variable Precedence (Lowest to Highest Priority)

Ansible applies variables in this order:

1. **Role defaults** (`roles/*/defaults/main.yml`)
2. **Inventory group_vars/all** (`inventories/group_vars/all/common.yml`)
3. **Inventory group_vars** (`inventories/group_vars/workstations/main.yml`)
4. **Inventory host_vars** (`inventories/host_vars/hostname/main.yml`)
5. **Playbook vars** (defined in playbook YAML)

**Example:**
```yaml
# 1. Role default (lowest priority)
# roles/utilities/defaults/main.yml
utilities_install_bat: true

# 2. Group vars override
# inventories/group_vars/workstations/main.yml
# utilities_install_bat: false  (this would override)

# 3. Host vars override (highest priority)
# inventories/host_vars/my-laptop/main.yml
# utilities_install_bat: true  (this would override both)
```

### Security Posture by Host Group

| Group | Hardening | SSH Port | Sudo | Use Case |
|-------|-----------|----------|------|----------|
| **workstations** | Minimal | 22 | Passwordless | Local dev machines |
| **servers** | Moderate | 22 | Password required | Homelab internal |
| **vps** | Maximum | Custom (65522) | Password required | Internet-facing |

**Configuration example:**

```yaml
# inventories/group_vars/workstations/main.yml
apply_hardening: false
sudo_passwordless_allowed: true
ufw_enabled: false

# inventories/group_vars/vps/main.yml
apply_hardening: true
hardening_enable_fail2ban: true
hardening_enable_ufw: true
hardening_enable_ssh_hardening: true
sudo_passwordless_allowed: false
ssh_custom_port: 65522
```

---

## Backward Compatibility Strategy

### Problem

When refactoring roles to add granular control, we must not break existing configurations.

### Solution: Computed Defaults

**Old way** (still works):
```yaml
# inventories/group_vars/workstations/main.yml
install_utilities: true  # Installs all utilities tools
```

**New way** (granular control):
```yaml
# inventories/group_vars/workstations/main.yml
install_utilities: true
utilities_install_bat: true
utilities_install_eza: true
utilities_install_lazygit: false  # Disable this one tool
```

**Implementation** (roles/utilities/defaults/main.yml):
```yaml
---
# Backward compatibility: if install_utilities is false, disable all
utilities_enabled: "{{ install_utilities | default(true) }}"

# Granular controls default to utilities_enabled state
utilities_install_bat: "{{ utilities_enabled | bool }}"
utilities_install_eza: "{{ utilities_enabled | bool }}"
utilities_install_lazygit: "{{ utilities_enabled | bool }}"
```

**Result:**
- Existing users: `install_utilities: true` → all tools installed
- New users: Can set individual tool flags
- Mixed: `install_utilities: true` + `utilities_install_lazygit: false` → all except lazygit

### Migration Path

1. **Phase 1**: Add new granular variables with computed defaults
2. **Phase 2**: Update documentation to show new approach
3. **Phase 3**: (Future) Deprecation notice for old flags
4. **Phase 4**: (Much later) Remove old flags

**Timeline**: Minimum 1 year between phases to allow user migration.

---

## Testing Strategy

### Three-Layer Testing Pyramid

**Layer 1: Molecule + Docker (Unit Tests)**
- Fast feedback (~30 seconds per role)
- Tests single role in isolation
- Multiple OS versions (Ubuntu, Debian)
- Validates idempotency
- Lightweight (Docker containers)

**Layer 2: LXD (Integration Tests)**
- Medium speed (~5-10 minutes per scenario)
- Tests complete playbooks
- Full OS with systemd, networking, users
- Multiple roles working together

**Layer 3: Proxmox (Acceptance Tests)**
- Slower (~15-30 minutes per scenario)
- Full VMs with real hardware emulation
- Cloud-init, networking, storage
- Closest to actual deployment environment

### When to Use Each Layer

| Development Phase | Layer 1 (Molecule) | Layer 2 (LXD) | Layer 3 (Proxmox) |
|-------------------|--------------------|--------------|--------------------|
| Writing code      | ✅ Continuous      | ❌            | ❌                  |
| Before commit     | ✅ All roles       | ❌            | ❌                  |
| Before PR merge   | ✅ All roles       | ✅ Scenarios  | ❌                  |
| Before deploy     | ✅ All roles       | ✅ Scenarios  | ✅ Full validation  |

---

## Security Approach

### Defense in Depth

Multiple layers of security controls:

1. **Minimal attack surface**: Only install necessary packages
2. **Least privilege**: No passwordless sudo in production (vps group)
3. **Network hardening**: UFW firewall with default-deny
4. **Access control**: SSH key-only authentication
5. **Intrusion detection**: fail2ban for brute-force protection
6. **System hardening**: OS-level controls (devsec.hardening)
7. **Automatic updates**: Unattended security patches

### Security by Host Group

**Workstations** (minimal security):
- Convenience over security
- Passwordless sudo (for testing)
- No firewall (easy access)
- SSH password auth allowed (if needed)

**Servers** (moderate security):
- Balanced security and usability
- Password-required sudo
- Firewall enabled (specific ports)
- Internal network (standard SSH port acceptable)
- fail2ban, OS hardening

**VPS** (maximum security):
- Security over convenience
- Password-required sudo
- Firewall enabled (default-deny)
- SSH key-only authentication
- Custom SSH port
- fail2ban enabled
- SSH and OS hardening
- Automatic security updates

### Hardening Role Design

**Granular control:**
```yaml
hardening_enable_fail2ban: true
hardening_enable_ufw: true
hardening_enable_ssh_hardening: true
hardening_enable_os_hardening: true
hardening_enable_unattended_upgrades: true
hardening_enable_suricata: false  # Optional (resource intensive)
```

**Benefits:**
- Enable only what you need
- Understand security controls applied
- Disable problematic features without modifying code
- Audit security posture from variables

### Secret Management

**Ansible Vault** for sensitive data:

```bash
# Create encrypted vault
ansible-vault create inventories/group_vars/all/vault.yml

# Store secrets
vault_database_password: "secret123"
vault_api_token: "token456"

# Use in tasks
- name: Configure database
  vars:
    db_password: "{{ vault_database_password }}"
```

**Best practices:**
- Never commit plaintext secrets
- Use vault for passwords, tokens, private keys
- Keep vault password in password manager
- Use different vault passwords per environment if needed

---

## Design Decisions

### Why Separate Task Files?

**Decision**: Use orchestrator pattern with separate task files per feature

**Rationale:**
- **Modularity**: Features can be toggled independently
- **Readability**: Each file is focused and easy to understand
- **Maintainability**: Changes to one feature don't affect others
- **Performance**: Only relevant tasks execute (when conditions in orchestrator)

**Alternative considered**: Monolithic main.yml with conditional blocks
**Rejected because**: Hard to read, difficult to maintain, all tasks evaluated even if skipped

### Why Role Defaults Instead of Group Vars?

**Decision**: Define variables in `roles/*/defaults/main.yml`

**Rationale:**
- **Discoverability**: Users know where to find role variables
- **Documentation**: Defaults serve as documentation
- **Precedence**: Lowest priority, easily overridden
- **Portability**: Role is self-contained with sensible defaults

**Alternative considered**: All variables in group_vars
**Rejected because**: Roles become non-portable, defaults unclear

### Why Host Groups by Purpose (Not Environment)?

**Decision**: Single inventory with workstations/servers/vps groups

**Rationale:**
- **Simpler**: One inventory, no `-i` flag needed
- **Intuitive**: "I have a laptop and a VPS" vs "Is this dev or prod?"
- **Less duplication**: group_vars defined once per host type
- **Flexible**: Can still have different security levels per group
- **Homelab-friendly**: Matches actual infrastructure, not deployment stages

**Alternative considered**: Separate dev/prod inventories
**Rejected because**: Overkill for homelab, unnecessary complexity

### Why Ansible Over Shell Scripts?

**Decision**: Use Ansible instead of bash scripts

**Rationale:**
- **Idempotency**: Built-in, difficult in bash
- **Multi-platform**: Ansible modules handle OS differences
- **Error handling**: Automatic, comprehensive
- **Testing**: Molecule, ansible-lint tooling
- **Declarative**: Describe desired state, not steps
- **Community**: Huge ecosystem of modules and roles

**Alternative considered**: Bash scripts with apt/dnf commands
**Rejected because**: Not idempotent, fragile, hard to test

---

## Future Considerations

### Multi-OS Support

**Current**: Ubuntu/Debian only
**Future**: Fedora, Rocky Linux, Arch

**Approach:**
- Use `ansible_os_family` conditions
- OS-specific variables in `roles/*/vars/`
- Package name mapping per OS
- Separate task files for significantly different approaches

### Role Dependencies

**Current**: Roles are independent
**Future**: Some roles may depend on others

**Example:**
```yaml
# roles/monitoring/meta/main.yml
dependencies:
  - role: utilities
    vars:
      utilities_install_tmux: true
```

**Consideration**: Limit dependencies to avoid complexity

### CI/CD Integration

**Current**: Manual testing
**Future**: Automated pipeline

**Pipeline stages:**
1. Lint (ansible-lint, yamllint)
2. Syntax check
3. Molecule tests (Layer 1)
4. LXD tests (Layer 2) - on PR only
5. Security scan (ansible-scan)
6. Documentation generation

---

*Last updated: 2026-02-10*
