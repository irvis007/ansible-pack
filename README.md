TODO:

# workstation

install:

- golang with golangci-lint, using GVM, https://golangci-lint.run/usage/install/#local-installation
- utilities, divide into
  - core: nextcloud client, obsidian, keepass, brave, signal, flameshot, p7zip-desktop, git, zsh, ohmyzsh, astroNvim,
  - optional: pomodoro, exercism, drawio, dbeaver-ce, okular

# server

install:

- security apps
  - fail2ban
  - ufw
- harden OS through automation
- harden components
- IDS/IPS

# common

- autoupdate; https://github.com/RealSalmon/ansible-unattended-upgrades/blob/master/tasks/main.yml

Sources:

- https://github.com/geerlingguy/ansible-role-nodejs/blob/master/tasks/main.yml
- https://github.com/LorenzoBettini/ansible-molecule-oh-my-zsh-example
