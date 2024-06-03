TODO:

# workstation
install:
- golang with golangci-lint, using GVM, https://golangci-lint.run/usage/install/#local-installation
- docker,
- terraform, 
- ansible, 
- utilities, divide into core, and optional (keepass, pomodoro, obsidian, brave, onedrive, nextcloud, exercism, drawio, dbeaver-ce, node, okular, p7zip-desktop, slack, kleopatra)

# server
install:
- security apps
    - fail2ban
    - ufw
- harden OS
- harden components
- IDS

common:
- autoupdate; https://github.com/RealSalmon/ansible-unattended-upgrades/blob/master/tasks/main.yml

Sources:
