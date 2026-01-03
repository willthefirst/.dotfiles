# Task: Make Hardcoded Paths Configurable for Testing

## Branch Name
`refactor/injectable-paths`

## Problem Statement
Several modules have hardcoded paths that make testing difficult. Tests must create real directories instead of being able to mock the filesystem.

### Hardcoded Paths Found

**In `lib/deploy.sh` (lines 26-36):**
```bash
mkdir -p "$HOME/.config"
mkdir -p "$HOME/.ssh/sockets"
```

**In `lib/backup.sh` (line 37):**
```bash
# Uses $HOME in timestamp/backup paths
```

**In `validate.sh` (lines 87-134):**
```bash
# Multiple $SCRIPT_DIR references
```

**In various files:**
- `/usr/local/bin` as install target
- `$HOME/.config` as config directory
- Temp directories like `/tmp`

### Issues
1. Tests require creating real directories
2. Can't test cross-platform behavior
3. No way to redirect file operations during tests
4. Cleanup is error-prone if tests fail mid-execution

## Desired Outcome
Key paths should be configurable via environment variables or function parameters, with sensible defaults that maintain current behavior.

## Implementation Steps

### 1. Identify All Hardcoded Paths

Run these searches:
```bash
grep -rn '\$HOME' lib/ --include="*.sh"
grep -rn '~/' lib/ --include="*.sh"
grep -rn '/usr/local/bin' . --include="*.sh"
grep -rn '/tmp' . --include="*.sh"
grep -rn '\.config' lib/ --include="*.sh"
grep -rn '\.ssh' lib/ --include="*.sh"
```

Create a list of all paths that need to be configurable.

### 2. Create Path Configuration in `lib/config.sh`

Add configurable path variables with defaults:

```bash
# ============================================
# Configurable Paths (can be overridden for testing)
# ============================================

# Base directories
: "${DOTFILES_HOME:=$HOME}"
: "${DOTFILES_CONFIG_DIR:=$DOTFILES_HOME/.config}"
: "${DOTFILES_SSH_DIR:=$DOTFILES_HOME/.ssh}"

# Install directories
: "${DOTFILES_BIN_DIR:=/usr/local/bin}"
: "${DOTFILES_TEMP_DIR:=/tmp}"

# Backup settings
: "${DOTFILES_BACKUP_DIR:=$DOTFILES_HOME}"

# Export for subshells
export DOTFILES_HOME DOTFILES_CONFIG_DIR DOTFILES_SSH_DIR
export DOTFILES_BIN_DIR DOTFILES_TEMP_DIR DOTFILES_BACKUP_DIR
```

The `: "${VAR:=default}"` pattern sets the variable only if not already set, allowing tests to override.

### 3. Update `lib/deploy.sh`

**Before:**
```bash
create_directories() {
    mkdir -p "$HOME/.config"
    mkdir -p "$HOME/.ssh/sockets"
    chmod 700 "$HOME/.ssh" 2>/dev/null || true
}
```

**After:**
```bash
create_directories() {
    mkdir -p "$DOTFILES_CONFIG_DIR"
    mkdir -p "$DOTFILES_SSH_DIR/sockets"
    chmod 700 "$DOTFILES_SSH_DIR" 2>/dev/null || true
}
```

### 4. Update `lib/backup.sh`

**Before:**
```bash
create_backup() {
    local backup_dir="$HOME/.dotfiles-backup-$(date +%Y%m%d_%H%M%S)"
    # ...
}
```

**After:**
```bash
create_backup() {
    local backup_dir="$DOTFILES_BACKUP_DIR/.dotfiles-backup-$(date +%Y%m%d_%H%M%S)"
    # ...
}
```

### 5. Update Install Scripts

**In `*/install.sh` files:**

Before:
```bash
sudo mv /tmp/binary /usr/local/bin/binary
```

After:
```bash
sudo mv "$DOTFILES_TEMP_DIR/binary" "$DOTFILES_BIN_DIR/binary"
```

### 6. Update Test Helpers

In `tests/helpers.sh`, set test-specific paths:

```bash
setup_test_env() {
    local create_dirs="${1:-true}"

    # Create isolated test directories
    TEST_ROOT=$(mktemp -d)

    # Override paths for testing
    export DOTFILES_HOME="$TEST_ROOT/home"
    export DOTFILES_CONFIG_DIR="$TEST_ROOT/home/.config"
    export DOTFILES_SSH_DIR="$TEST_ROOT/home/.ssh"
    export DOTFILES_BIN_DIR="$TEST_ROOT/bin"
    export DOTFILES_TEMP_DIR="$TEST_ROOT/tmp"
    export DOTFILES_BACKUP_DIR="$TEST_ROOT/home"

    if [[ "$create_dirs" == "true" ]]; then
        mkdir -p "$DOTFILES_HOME"
        mkdir -p "$DOTFILES_CONFIG_DIR"
        mkdir -p "$DOTFILES_SSH_DIR"
        mkdir -p "$DOTFILES_BIN_DIR"
        mkdir -p "$DOTFILES_TEMP_DIR"
    fi

    # ... rest of setup ...
}

teardown_test_env() {
    # Clean up test directories
    [[ -d "$TEST_ROOT" ]] && rm -rf "$TEST_ROOT"

    # Unset test overrides
    unset DOTFILES_HOME DOTFILES_CONFIG_DIR DOTFILES_SSH_DIR
    unset DOTFILES_BIN_DIR DOTFILES_TEMP_DIR DOTFILES_BACKUP_DIR

    # ... rest of teardown ...
}
```

### 7. Handle sudo Operations

For operations that normally require sudo (like installing to `/usr/local/bin`), add a helper:

```bash
# In lib/install-helpers.sh or lib/fs.sh

# Install file to directory, using sudo only if needed
install_to_dir() {
    local source="$1"
    local dest_dir="$2"
    local name="$3"

    if [[ -w "$dest_dir" ]]; then
        mv "$source" "$dest_dir/$name"
    else
        sudo mv "$source" "$dest_dir/$name"
    fi
}
```

This automatically skips sudo when the test overrides `DOTFILES_BIN_DIR` to a writable test directory.

### 8. Update Documentation

Add comments explaining the configurable paths:

```bash
# lib/config.sh

# =================================================================
# Path Configuration
# =================================================================
# These paths can be overridden by setting environment variables
# before sourcing this file. This is useful for:
# - Testing (redirect to temp directories)
# - Custom installations (different target paths)
# - Containerized environments
#
# Example (for testing):
#   export DOTFILES_HOME=/tmp/test-home
#   source lib/config.sh
# =================================================================
```

### 9. Verify No Remaining Hardcoded Paths

After refactoring, run:
```bash
# Should find no results in lib/ (except the defaults in config.sh)
grep -rn '\$HOME' lib/ --include="*.sh" | grep -v 'DOTFILES_HOME'
grep -rn '~/' lib/ --include="*.sh"
grep -rn '/usr/local/bin' lib/ --include="*.sh" | grep -v 'DOTFILES_BIN_DIR'
```

## Files to Modify
- `lib/config.sh` (MODIFY - add path configuration)
- `lib/deploy.sh` (MODIFY - use configurable paths)
- `lib/backup.sh` (MODIFY - use configurable paths)
- `lib/fs.sh` (MODIFY - may need updates)
- `*/install.sh` files (MODIFY - use configurable paths)
- `tests/helpers.sh` (MODIFY - set test paths)
- `validate.sh` (MODIFY - use configurable paths where appropriate)

## Testing
```bash
# Test that defaults work (normal execution)
./validate.sh
./install.sh --dry-run base

# Test that overrides work
export DOTFILES_HOME=/tmp/test-home
mkdir -p /tmp/test-home
source lib/config.sh
echo "Config dir: $DOTFILES_CONFIG_DIR"  # Should show /tmp/test-home/.config

# Run test suite (uses overrides automatically)
./tests/run_tests.sh
```

## Success Criteria
- [ ] Path variables defined in `lib/config.sh` with defaults
- [ ] `lib/deploy.sh` uses `$DOTFILES_CONFIG_DIR` and `$DOTFILES_SSH_DIR`
- [ ] `lib/backup.sh` uses `$DOTFILES_BACKUP_DIR`
- [ ] Install scripts use `$DOTFILES_BIN_DIR` and `$DOTFILES_TEMP_DIR`
- [ ] Test helpers override paths to isolated directories
- [ ] Normal execution (without overrides) works exactly as before
- [ ] All tests pass
- [ ] No hardcoded `$HOME`, `~`, or `/usr/local/bin` in library files (except defaults)
