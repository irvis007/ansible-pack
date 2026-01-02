.PHONY: help setup install-molecule lint test-role test-all clean

# Variables
INVENTORY ?= development
ENV ?= development
ROLE ?= zsh
PLATFORM ?= all

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

help:
	@echo "$(BLUE)Ansible Pack - Available Commands$(NC)"
	@echo ""
	@echo "$(GREEN)Setup:$(NC)"
	@echo "  make setup              - Install Ansible dependencies (collections, roles)"
	@echo "  make install-molecule   - Install Molecule for testing"
	@echo ""
	@echo "$(GREEN)Testing (Layer 1 - Molecule/Docker):$(NC)"
	@echo "  make test-role ROLE=zsh           - Test specific role with Molecule"
	@echo "  make test-all                     - Test all roles with Molecule"
	@echo "  make molecule-create ROLE=zsh     - Create test containers"
	@echo "  make molecule-converge ROLE=zsh   - Apply role to containers"
	@echo "  make molecule-verify ROLE=zsh     - Run verification tests"
	@echo "  make molecule-destroy ROLE=zsh    - Destroy test containers"
	@echo "  make molecule-login ROLE=zsh      - Login to test container"
	@echo ""
	@echo "$(GREEN)Testing (Layer 2 - LXD):$(NC)"
	@echo "  make lxd-create NAME=test-workstation-ubuntu - Create LXD container"
	@echo "  make lxd-test-workstation         - Test workstation setup in LXD"
	@echo "  make lxd-test-server              - Test server hardening in LXD"
	@echo "  make lxd-test-all                 - Run all LXD integration tests"
	@echo "  make lxd-clean                    - Clean up LXD test containers"
	@echo ""
	@echo "$(GREEN)Code Quality:$(NC)"
	@echo "  make lint               - Run ansible-lint and yamllint"
	@echo "  make syntax-check       - Check playbook syntax"
	@echo ""
	@echo "$(GREEN)Playbooks:$(NC)"
	@echo "  make workstation-local  - Setup workstation on localhost"
	@echo "  make server-dev         - Setup server in dev environment"
	@echo "  make dry-run PLAYBOOK=workstation_setup - Dry run playbook"
	@echo ""
	@echo "$(GREEN)Cleanup:$(NC)"
	@echo "  make clean              - Clean temporary files and containers"
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make test-role ROLE=zsh          # Test ZSH role (Layer 1)"
	@echo "  make lxd-test-workstation        # Test full workstation (Layer 2)"
	@echo "  make lint                        # Check code quality"

# ============================================================================
# Setup & Installation
# ============================================================================

setup:
	@echo "$(BLUE)Installing Ansible dependencies...$(NC)"
	ansible-galaxy collection install -r meta/requirements.yml
	ansible-galaxy role install -r meta/requirements.yml
	@echo "$(GREEN)✓ Dependencies installed$(NC)"

install-molecule:
	@echo "$(BLUE)Installing Molecule and testing tools...$(NC)"
	@echo "$(YELLOW)Note: This will install in your current Python environment$(NC)"
	@echo "Consider using a virtual environment:"
	@echo "  python3 -m venv ~/.venv/ansible-testing"
	@echo "  source ~/.venv/ansible-testing/bin/activate"
	@echo ""
	@read -p "Continue? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		pip3 install --user molecule molecule-docker ansible ansible-lint yamllint; \
		echo "$(GREEN)✓ Molecule installed$(NC)"; \
		molecule --version; \
	fi

# ============================================================================
# Testing - Layer 1: Molecule (Docker)
# ============================================================================

test-role:
	@if [ ! -d "roles/$(ROLE)/molecule" ]; then \
		echo "$(RED)✗ Role $(ROLE) has no Molecule tests$(NC)"; \
		echo "Available roles with tests:"; \
		find roles -name "molecule" -type d | sed 's|roles/\(.*\)/molecule|\1|' | sed 's/^/  - /'; \
		exit 1; \
	fi
	@echo "$(BLUE)Testing role: $(ROLE)$(NC)"
	cd roles/$(ROLE) && molecule test
	@echo "$(GREEN)✓ Role $(ROLE) tests passed$(NC)"

test-all:
	@echo "$(BLUE)Testing all roles with Molecule tests...$(NC)"
	@for role in $$(find roles -name "molecule" -type d | sed 's|roles/\(.*\)/molecule|\1|'); do \
		echo "$(YELLOW)Testing $$role...$(NC)"; \
		cd roles/$$role && molecule test || exit 1; \
		cd ../..; \
	done
	@echo "$(GREEN)✓ All role tests passed$(NC)"

molecule-create:
	@echo "$(BLUE)Creating test containers for role: $(ROLE)$(NC)"
	cd roles/$(ROLE) && molecule create
	@echo "$(GREEN)✓ Containers created$(NC)"
	@echo "Use 'make molecule-converge ROLE=$(ROLE)' to apply the role"

molecule-converge:
	@echo "$(BLUE)Applying role $(ROLE) to test containers...$(NC)"
	cd roles/$(ROLE) && molecule converge
	@echo "$(GREEN)✓ Role applied$(NC)"

molecule-verify:
	@echo "$(BLUE)Verifying role $(ROLE)...$(NC)"
	cd roles/$(ROLE) && molecule verify
	@echo "$(GREEN)✓ Verification passed$(NC)"

molecule-destroy:
	@echo "$(BLUE)Destroying test containers for role: $(ROLE)$(NC)"
	cd roles/$(ROLE) && molecule destroy
	@echo "$(GREEN)✓ Containers destroyed$(NC)"

molecule-login:
	@echo "$(BLUE)Logging into test container for role: $(ROLE)$(NC)"
	@echo "$(YELLOW)Available instances:$(NC)"
	@cd roles/$(ROLE) && molecule list
	@echo ""
	@read -p "Instance name (default: first available): " INSTANCE; \
	cd roles/$(ROLE) && \
	if [ -z "$$INSTANCE" ]; then \
		molecule login; \
	else \
		molecule login -h $$INSTANCE; \
	fi

# ============================================================================
# Code Quality
# ============================================================================

lint:
	@echo "$(BLUE)Running ansible-lint...$(NC)"
	@if command -v ansible-lint >/dev/null 2>&1; then \
		ansible-lint playbooks/ roles/ || true; \
	else \
		echo "$(RED)ansible-lint not installed$(NC)"; \
		echo "Install with: pip3 install ansible-lint"; \
		exit 1; \
	fi
	@echo ""
	@echo "$(BLUE)Running yamllint...$(NC)"
	@if command -v yamllint >/dev/null 2>&1; then \
		yamllint playbooks/ roles/ inventories/ || true; \
	else \
		echo "$(YELLOW)yamllint not installed (optional)$(NC)"; \
		echo "Install with: pip3 install yamllint"; \
	fi
	@echo "$(GREEN)✓ Linting complete$(NC)"

syntax-check:
	@echo "$(BLUE)Checking playbook syntax...$(NC)"
	ansible-playbook playbooks/workstation_setup.yml --syntax-check
	ansible-playbook playbooks/server_setup.yml --syntax-check
	@echo "$(GREEN)✓ Syntax check passed$(NC)"

# ============================================================================
# Playbooks
# ============================================================================

workstation-local:
	@echo "$(BLUE)Setting up workstation on localhost...$(NC)"
	@echo "$(YELLOW)⚠  This will modify your local machine!$(NC)"
	@read -p "Continue? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		ansible-playbook playbooks/workstation_setup.yml \
			-i inventories/$(ENV)/hosts.yml \
			-l localhost \
			--ask-become-pass \
			--diff; \
	fi

server-dev:
	@echo "$(BLUE)Setting up server in development environment...$(NC)"
	ansible-playbook playbooks/server_setup.yml \
		-i inventories/development/hosts.yml \
		--ask-become-pass \
		--diff

dry-run:
	@echo "$(BLUE)Dry run: playbooks/$(PLAYBOOK).yml$(NC)"
	ansible-playbook playbooks/$(PLAYBOOK).yml \
		-i inventories/$(ENV)/hosts.yml \
		--check \
		--diff

# ============================================================================
# LXD Integration Testing (Layer 2)
# ============================================================================

LXD_NAME ?= test-workstation-ubuntu
LXD_IMAGE ?= ubuntu:22.04

lxd-check:
	@if ! command -v lxc >/dev/null 2>&1; then \
		echo "$(RED)ERROR: LXD is not installed$(NC)"; \
		echo "Install with: sudo snap install lxd"; \
		exit 1; \
	fi

lxd-create: lxd-check
	@echo "$(BLUE)Creating LXD container: $(LXD_NAME)$(NC)"
	@./tests/lxd/scripts/setup_container.sh $(LXD_NAME) $(LXD_IMAGE)

lxd-test-workstation: lxd-check
	@echo "$(BLUE)Running workstation integration tests...$(NC)"
	@./tests/lxd/scripts/run_tests.sh workstation no

lxd-test-server: lxd-check
	@echo "$(BLUE)Running server integration tests...$(NC)"
	@./tests/lxd/scripts/run_tests.sh server no

lxd-test-all: lxd-check
	@echo "$(BLUE)Running all LXD integration tests...$(NC)"
	@./tests/lxd/scripts/run_tests.sh all yes

lxd-clean: lxd-check
	@echo "$(BLUE)Cleaning up LXD test containers...$(NC)"
	@./tests/lxd/scripts/cleanup.sh

lxd-list: lxd-check
	@echo "$(BLUE)LXD containers:$(NC)"
	@lxc list

# ============================================================================
# Cleanup
# ============================================================================

clean:
	@echo "$(BLUE)Cleaning temporary files...$(NC)"
	find . -name "*.retry" -delete
	find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	rm -rf .cache/ .pytest_cache/
	@echo "$(BLUE)Cleaning Docker containers...$(NC)"
	@docker ps -a | grep molecule | awk '{print $$1}' | xargs docker rm -f 2>/dev/null || true
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

# ============================================================================
# Information
# ============================================================================

info:
	@echo "$(BLUE)Ansible Pack Information$(NC)"
	@echo ""
	@echo "Environment: $(ENV)"
	@echo "Inventory: inventories/$(ENV)/hosts.yml"
	@echo ""
	@echo "Ansible version:"
	@ansible --version | head -1
	@echo ""
	@echo "Molecule installed:"
	@if command -v molecule >/dev/null 2>&1; then \
		molecule --version; \
	else \
		echo "  $(RED)Not installed$(NC)"; \
	fi
	@echo ""
	@echo "Docker status:"
	@if command -v docker >/dev/null 2>&1; then \
		docker --version; \
		docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | grep molecule || echo "  No Molecule containers running"; \
	else \
		echo "  $(RED)Not installed$(NC)"; \
	fi
	@echo ""
	@echo "Roles with Molecule tests:"
	@find roles -name "molecule" -type d | sed 's|roles/\(.*\)/molecule|  - \1|' || echo "  None found"

# ============================================================================
# Development helpers
# ============================================================================

watch-role:
	@echo "$(BLUE)Watching role $(ROLE) for changes...$(NC)"
	@echo "$(YELLOW)Will run 'molecule converge' on file changes$(NC)"
	@echo "Press Ctrl+C to stop"
	@while true; do \
		inotifywait -r -e modify roles/$(ROLE) 2>/dev/null && \
		cd roles/$(ROLE) && molecule converge; \
	done

# Quick checks before commit
pre-commit: lint syntax-check
	@echo "$(GREEN)✓ Pre-commit checks passed$(NC)"
	@echo "$(YELLOW)Consider running: make test-all$(NC)"
