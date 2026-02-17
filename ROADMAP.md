# Ansible Pack Roadmap

This roadmap tracks planned features, improvements, and priorities for the ansible-pack project.

## Done ✅

### Version 1.5.0 (2026-02-17)\n- See [CHANGELOG.md](CHANGELOG.md) for details\n

### Version 1.4.5 (2026-02-17)\n- See [CHANGELOG.md](CHANGELOG.md) for details\n

### Version 1.4.4 (2026-02-17)\n- See [CHANGELOG.md](CHANGELOG.md) for details\n

### Version 1.4.3 (2026-02-17)\n- See [CHANGELOG.md](CHANGELOG.md) for details\n

### Version 1.4.2 (2026-02-17)\n- See [CHANGELOG.md](CHANGELOG.md) for details\n

### Version 1.4.1 (2026-02-17)\n- See [CHANGELOG.md](CHANGELOG.md) for details\n

### Version 1.4.0 (2026-02-17)\n- See [CHANGELOG.md](CHANGELOG.md) for details\n

### Version 1.3.0 (2026-02-11)\n- See [CHANGELOG.md](CHANGELOG.md) for details\n

### Version 1.2.0 (2026-02-11)\n- See [CHANGELOG.md](CHANGELOG.md) for details\n

### Version 1.1.0 (2026-02-11)\n- See [CHANGELOG.md](CHANGELOG.md) for details\n

### Version 1.0.0 (2026-02-11)\n- See [CHANGELOG.md](CHANGELOG.md) for details\n

### 2024-2025
- ✅ Core roles: zsh, nvim, utilities, fonts, bootstrap, hardening
- ✅ Testing framework (3-layer: Molecule/Docker → LXD → Proxmox)
- ✅ Development/Production environment separation
- ✅ Comprehensive README and documentation
- ✅ Makefile automation for testing and deployment
- ✅ Suricata IDS integration in hardening role
- ✅ Repository restructuring and organization

---

## Now 🔨 (Current Quarter)

### Documentation Overhaul
- [ ] Consolidate testing docs (9 files → 1 TESTING.md)
- [ ] Create HOW-TO.md with practical recipes
- [ ] Create REFERENCE.md with complete variable documentation
- [ ] Create ARCHITECTURE.md documenting design decisions
- [ ] Slim down README.md (460 → 150 lines)
- [x] This ROADMAP.md file

### Enhanced Modularity
- [ ] Refactor utilities role with granular tool control
  - Per-tool flags: `utilities_install_bat`, `utilities_install_eza`, etc.
  - Backward compatibility maintained
- [ ] Create devops-tools role (Docker, Terragrunt, tenv)
- [ ] Create cloud-tools role (kubectl, aws-cli)
- [ ] Add per-tool feature flags across all roles

### Hardening Role Activation
- [ ] Uncomment and configure fail2ban tasks
- [ ] Uncomment and configure UFW firewall tasks
- [ ] Uncomment SSH hardening (devsec.hardening.ssh_hardening)
- [ ] Uncomment OS hardening (devsec.hardening.os_hardening)
- [ ] Uncomment unattended-upgrades tasks
- [ ] Create defaults/main.yml with granular hardening controls

---

## Next 📋 (Next Quarter)

### New Tools & Technologies
- [ ] Terragrunt support in devops-tools role
- [ ] tenv/tfenv integration for Terraform version management
- [ ] kubectl installation in cloud-tools role
- [ ] AWS CLI support
- [ ] Google Cloud SDK (optional)
- [ ] Azure CLI (optional)

### VPS & Server Features
- [ ] VPS-specific playbook (vps_setup.yml)
- [ ] Monitoring role (node-exporter, basic metrics)
- [ ] Backup automation scripts
- [ ] Log aggregation setup
- [ ] Automated security updates validation

### Testing & Validation
- [ ] Post-installation validation tasks for all roles
- [ ] Quick smoke tests per role
- [ ] Expand Molecule coverage (all roles, not just zsh)
- [ ] Create validate.yml playbook
- [ ] Add idempotency tests for all roles

### Use Case Optimization
- [ ] Ansible development environment playbook (ansible_dev.yml)
- [ ] Work machine profile/inventory examples
- [ ] Private laptop profile/inventory examples
- [ ] Homelab server profile/inventory examples

---

## Later 🔮 (Future / Backlog)

### Multi-OS Support
- [ ] Fedora support
- [ ] Rocky Linux / AlmaLinux support
- [ ] Arch Linux support
- [ ] Debian testing/sid support
- [ ] Ubuntu LTS version matrix testing

### Advanced Features
- [ ] Nextcloud client setup
- [ ] KeePass / KeePassXC installation
- [ ] Golang with GVM
- [ ] Python with pyenv
- [ ] Ruby with rbenv
- [ ] Node.js with nvm (currently included with nvim role)

### Infrastructure & Automation
- [ ] CI/CD pipeline integration (GitHub Actions / GitLab CI)
- [ ] Pre-commit hooks for local development
- [ ] Automated release process
- [ ] Checksum verification for all downloads
- [ ] GPG signature verification where available

### Additional Roles
- [ ] backup role (automated backups with restic/borg)
- [ ] container-management role (podman as alternative to docker)
- [ ] database role (PostgreSQL, MySQL, Redis)
- [ ] webserver role (nginx, caddy)
- [ ] reverse-proxy role (traefik, nginx-proxy)
- [ ] vpn role (WireGuard, OpenVPN)

### Documentation & Community
- [ ] Video tutorials for common use cases
- [ ] Ansible best practices guide
- [ ] Contributing guidelines
- [ ] Issue templates
- [ ] Pull request templates
- [ ] Changelog automation

---

## Versioning

This project follows **semantic versioning** principles:
- **Major** (1.0, 2.0): Breaking changes, major redesigns
- **Minor** (1.1, 1.2): New features, backward compatible
- **Patch** (1.1.1, 1.1.2): Bug fixes, minor improvements

Current focus is on reaching **v1.0** with:
- ✅ Stable role structure
- ✅ Comprehensive testing
- ⏳ Complete documentation
- ⏳ Production-ready hardening

---

*Last updated: 2026-02-10*
