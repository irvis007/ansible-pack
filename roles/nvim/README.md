# Neovim & AstroNvim Role

Role for installing Neovim and AstroNvim

## Features

- **Latest Neovim**: Official pre-built binary from GitHub (always fresh)
- **AstroNvim v5**: Your personal fork with config backup/restore
- **Modular Dependencies**: Feature flags for all optional dependencies
- **Backup Support**: Automatic backup of existing config
- **Multiple Install Methods**: User repo / Template / User repo with upstream
- **Node.js Setup**: Automatic Node.js 20.x installation
- **Clean Architecture**: Orchestrator pattern with modular task files

## Quick Start

```yaml
# In your inventory (e.g., inventories/group_vars/workstations/main.yml)
install_astronvim: true

# Optional: Customize repo
nvim_user_repo: "https://github.com/irvis007/astro-vim-v5.git"

# Optional: Disable specific dependencies
nvim_install_bottom: false
nvim_install_terminator: false
```

Run:

```bash
ansible-playbook playbooks/workstation_setup.yml --tags nvim
```

## Installation Methods

### Method 1: user_repo (Default - Recommended)

Clone your complete AstroNvim fork (includes base + your config):

```yaml
nvim_install_method: "user_repo" # Default
nvim_user_repo: "https://github.com/irvis007/astro-vim-v5.git"
```

### Method 2: template

Clone official AstroNvim template only (vanilla setup):

```yaml
nvim_install_method: "template"
```

### Method 3: user_repo_with_upstream

Clone your repo + add upstream remote for easy template updates:

```yaml
nvim_install_method: "user_repo_with_upstream"
```

## Dependencies Control

### Required Dependencies (Always Installed)

- Node.js 20.x (for language servers)
- Core build tools: git, tar, build-essential, cmake
- AstroNvim requirements: fd-find, ripgrep

### Optional Dependencies (Feature Flags)

```yaml
nvim_install_clipboard: true # Default: true
nvim_clipboard_tool: "xclip" # Options: xclip, xsel

# Git UI
nvim_install_lazygit: true # Default: true

# Disk usage viewer
nvim_install_gdu: true # Default: true

# Process viewer
nvim_install_bottom: true # Default: true

# Tree-sitter CLI (for auto_install)
nvim_install_treesitter_cli: true # Default: true

# Python support (for Python plugins/REPL)
nvim_install_python_provider: true # Default: true

# Terminal emulator
nvim_install_terminator: false # Default: false
```

## Backup Configuration

Existing `~/.config/nvim` is automatically backed up before installation:

```yaml
nvim_backup_existing: true # Default: true
nvim_backup_dir: "~/.config/nvim.backup.{{ ansible_date_time.epoch }}"
```

Disable backup:

```yaml
nvim_backup_existing: false
```

## Configuration Variables

### Repository Settings

```yaml
nvim_user_repo: "https://github.com/irvis007/astro-vim-v5.git"
nvim_template_repo: "https://github.com/AstroNvim/template.git"
nvim_config_dir: "{{ ansible_env.HOME }}/.config/nvim"
```

### Node.js Settings

```yaml
nodejs_version: "20.x"
nodejs_install_npm_user: "{{ ansible_user_id }}" # Auto-detected
npm_config_prefix: "/usr/local/lib/npm"
nodejs_npm_global_packages: [] # Additional npm packages
```

### Initialization

```yaml
nvim_run_initialization: true
nvim_init_command: "nvim --headless -c 'quitall'"
```

## Example Configurations

### Minimal Installation (Neovim + AstroNvim only)

```yaml
nvim_install_clipboard: true # Keep for clipboard support
nvim_install_lazygit: false
nvim_install_gdu: false
nvim_install_bottom: false
nvim_install_treesitter_cli: false
nvim_install_python_provider: false
```

### Full-Featured Workstation

```yaml
nvim_install_method: "user_repo_with_upstream"
nvim_install_clipboard: true
nvim_install_lazygit: true
nvim_install_gdu: true
nvim_install_bottom: true
nvim_install_treesitter_cli: true
nvim_install_python_provider: true
```

### Testing/Development (Vanilla Template)

```yaml
nvim_install_method: "template"
nvim_backup_existing: true
```

## Updating AstroNvim Template

If using `user_repo_with_upstream` method:

```bash
cd ~/.config/nvim
git fetch upstream
git merge upstream/main  # Carefully merge template updates
```
