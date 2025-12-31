# Testing Quick Start

Get started with testing in 5 minutes!

## Prerequisites Check

```bash
# Check if you have what you need
docker --version          # Should be installed
python3 --version         # Should be 3.8+
ansible --version         # Should be 2.14+
```

If Docker is missing:
```bash
sudo apt install docker.io
sudo usermod -aG docker $USER
# Log out and back in
```

## Step 1: Install Molecule (One-time Setup)

```bash
# Option A: Global install (easiest)
make install-molecule

# Option B: Virtual environment (recommended for isolation)
python3 -m venv ~/.venv/ansible-testing
source ~/.venv/ansible-testing/bin/activate
pip install molecule molecule-docker ansible ansible-lint yamllint
```

Verify installation:
```bash
molecule --version
# Should show: molecule 6.x.x using python 3.x
```

## Step 2: Run Your First Test

```bash
# Test the ZSH role (takes ~30 seconds)
make test-role ROLE=zsh
```

You'll see:
1. ✓ Container creation (Ubuntu 22.04 and Debian 12)
2. ✓ Role application
3. ✓ Idempotency check (role runs again, no changes)
4. ✓ Verification tests
5. ✓ Cleanup

**Success looks like:**
```
PLAY RECAP *****************************
zsh-ubuntu22: ok=XX changed=0 unreachable=0 failed=0
zsh-debian12: ok=XX changed=0 unreachable=0 failed=0

✓ Role zsh tests passed
```

## Step 3: Interactive Development

Instead of full test cycle, develop interactively:

```bash
# 1. Create containers once
make molecule-create ROLE=zsh

# 2. Make changes to roles/zsh/tasks/main.yml

# 3. Apply changes (fast, ~10 seconds)
make molecule-converge ROLE=zsh

# 4. Repeat steps 2-3 as needed

# 5. Verify it works
make molecule-verify ROLE=zsh

# 6. Login to debug (optional)
make molecule-login ROLE=zsh

# 7. Cleanup when done
make molecule-destroy ROLE=zsh
```

## Step 4: Test Before Committing

```bash
# Check code quality
make lint

# Check syntax
make syntax-check

# Run pre-commit checks (runs both above)
make pre-commit
```

## Common Workflows

### Daily Development

```bash
# Quick iteration loop
cd roles/zsh
molecule create           # Once per session
molecule converge         # After each change
molecule verify           # Check if it works
molecule destroy          # When done

# Or use Makefile shortcuts
make molecule-create ROLE=zsh
make molecule-converge ROLE=zsh
make molecule-verify ROLE=zsh
```

### Before Committing

```bash
# Full test suite for one role
make test-role ROLE=zsh

# Test all roles (if you changed common code)
make test-all

# Quick quality checks
make pre-commit
```

### Debugging a Failed Test

```bash
# Create and apply role
make molecule-create ROLE=zsh
make molecule-converge ROLE=zsh

# Login to container to investigate
make molecule-login ROLE=zsh

# Inside container:
zsh --version
ls -la ~/.oh-my-zsh
cat /var/log/syslog

# Exit container (Ctrl+D)
# Fix the issue in your role
# Re-apply
make molecule-converge ROLE=zsh
```

## Understanding the Output

### Successful Run
```
TASK [Include zsh role] ****
ok: [zsh-ubuntu22]
ok: [zsh-debian12]

changed=0   ← Good! Idempotent
failed=0    ← Good! No failures
```

### Idempotency Failure
```
TASK [Include zsh role] ****
changed: [zsh-ubuntu22]  ← Bad! Changed on second run

CRITICAL: Idempotence test failed
```

**Fix**: Add `changed_when: false` to tasks that always show as changed but don't actually change anything.

### Failed Verification
```
TASK [Verify Oh-My-Zsh installation] ****
fatal: [zsh-ubuntu22]: FAILED!

✗ Role zsh tests failed
```

**Fix**:
1. Check what verification expected vs what happened
2. Login to container: `make molecule-login ROLE=zsh`
3. Manually verify the issue
4. Fix your role
5. Re-test

## Tips & Tricks

### Speed Up Tests

```bash
# Skip destroy to keep containers between runs
cd roles/zsh
molecule converge  # Faster than full 'molecule test'
```

### Test Specific OS

```bash
# Edit roles/zsh/molecule/default/molecule.yml
# Comment out platforms you don't need temporarily

platforms:
  - name: zsh-ubuntu22
    # ...
  # - name: zsh-debian12  ← Commented out
```

### See What's Happening

```bash
# More verbose output
cd roles/zsh
molecule --debug converge
```

### Clean Everything

```bash
# Remove all test containers and temp files
make clean
```

### Check Current State

```bash
# See what's running
make info

# Or directly
docker ps | grep molecule
```

## Troubleshooting

### "Cannot connect to Docker daemon"

```bash
# Start Docker
sudo systemctl start docker

# Add yourself to docker group
sudo usermod -aG docker $USER
# Log out and back in
```

### "Command not found: molecule"

```bash
# Install Molecule
make install-molecule

# Or activate virtual environment
source ~/.venv/ansible-testing/bin/activate
```

### "Idempotence test failed"

Your role is making changes on the second run. Find the task that changed:

```yaml
# Bad: Command always reports as changed
- name: Check version
  command: zsh --version

# Good: Tell Ansible this doesn't change anything
- name: Check version
  command: zsh --version
  changed_when: false
```

### Containers Won't Start

```bash
# Clean everything
make clean

# Remove old containers
docker container prune -f

# Try again
make test-role ROLE=zsh
```

### Tests Pass but Real System Fails

Docker containers are not 100% identical to real systems:
1. Limited systemd functionality
2. Different filesystem layout
3. No kernel modules

**Solution**: Add Layer 2 testing (LXD) for more realistic testing.

## Next Steps

Once comfortable with Molecule:

1. **Add tests to other roles**
   ```bash
   # Copy molecule setup from zsh to another role
   cp -r roles/zsh/molecule roles/nvim/
   # Edit roles/nvim/molecule/default/converge.yml
   ```

2. **Set up CI/CD** (see docs/CI_CD.md)
   - Auto-run tests on every commit
   - Test on multiple OS versions
   - Block merges if tests fail

3. **Move to Layer 2**: Integration testing with LXD
   - More realistic (full OS)
   - Test complete playbooks
   - Slower but catches more issues

## Quick Reference

```bash
# Test commands
make test-role ROLE=zsh        # Full test cycle
make molecule-create ROLE=zsh  # Create containers
make molecule-converge ROLE=zsh # Apply role
make molecule-verify ROLE=zsh  # Run tests
make molecule-destroy ROLE=zsh # Cleanup
make molecule-login ROLE=zsh   # Debug

# Quality checks
make lint                      # Check code quality
make syntax-check              # Validate syntax
make pre-commit                # Run all checks

# Information
make info                      # Show environment info
make help                      # Show all commands
```

## Getting Help

- **Molecule docs**: https://molecule.readthedocs.io/
- **This repo's full testing guide**: docs/TESTING.md
- **Create an issue**: If something's not working

Happy testing! 🧪
