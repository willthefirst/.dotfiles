# Task: Create Explicit Module Initialization System

## Branch Name
`refactor/module-initialization`

## Problem Statement
Scripts manually source modules assuming a specific order, with no validation that dependencies are met. This creates fragile implicit dependencies.

### Current State

**In `install.sh` (lines 14-27):**
```bash
source "$SCRIPT_DIR/lib/common.sh"  # Sources log, platform, fs
source "$SCRIPT_DIR/lib/config.sh"  # Assumes log is available
source "$SCRIPT_DIR/lib/deploy.sh"
source "$SCRIPT_DIR/lib/deps.sh"    # Assumes DOTFILES_DIR from config
# ...
```

**In `lib/common.sh` (lines 24-29):**
```bash
source "${BASH_SOURCE%/*}/log.sh"
source "${BASH_SOURCE%/*}/platform.sh"
source "${BASH_SOURCE%/*}/fs.sh"
```

**In `lib/config.sh` (line 11):**
```bash
source "${BASH_SOURCE%/*}/log.sh"  # Redundant if common.sh already loaded
```

### Issues
1. **Order-dependent**: Scripts break if sourced in wrong order
2. **Redundant sourcing**: Same file may be sourced multiple times
3. **Hidden dependencies**: No way to know what a module requires
4. **Circular risk**: Potential for circular dependencies
5. **No validation**: Modules assume dependencies are met

## Desired Outcome
1. Explicit dependency declarations in each module
2. Single initialization point that handles all modules correctly
3. Protection against redundant sourcing
4. Validation that dependencies are available

## Implementation Steps

### 1. Add Source Guards to All Modules

Prevent multiple sourcing with guards:

```bash
# At top of lib/log.sh
[[ -n "${_DOTFILES_LOG_LOADED:-}" ]] && return 0
_DOTFILES_LOG_LOADED=1

# ... rest of module ...
```

Add to all library files:
- `lib/log.sh` → `_DOTFILES_LOG_LOADED`
- `lib/platform.sh` → `_DOTFILES_PLATFORM_LOADED`
- `lib/fs.sh` → `_DOTFILES_FS_LOADED`
- `lib/config.sh` → `_DOTFILES_CONFIG_LOADED`
- `lib/common.sh` → `_DOTFILES_COMMON_LOADED`
- `lib/deploy.sh` → `_DOTFILES_DEPLOY_LOADED`
- `lib/deps.sh` → `_DOTFILES_DEPS_LOADED`
- `lib/backup.sh` → `_DOTFILES_BACKUP_LOADED`
- `lib/conflicts.sh` → `_DOTFILES_CONFLICTS_LOADED`
- `lib/verify.sh` → `_DOTFILES_VERIFY_LOADED`

### 2. Document Dependencies in Each Module

Add header comments declaring dependencies:

```bash
#!/usr/bin/env bash
# =================================================================
# lib/deploy.sh - Package deployment functions
# =================================================================
# Dependencies: log.sh, fs.sh, config.sh
# Provides: deploy_packages, deploy_base, create_directories
# =================================================================

[[ -n "${_DOTFILES_DEPLOY_LOADED:-}" ]] && return 0
_DOTFILES_DEPLOY_LOADED=1

# Source dependencies (guards prevent double-loading)
source "${BASH_SOURCE%/*}/log.sh"
source "${BASH_SOURCE%/*}/fs.sh"
source "${BASH_SOURCE%/*}/config.sh"

# ... rest of module ...
```

### 3. Create Dependency Graph

Document the actual dependency tree:

```
lib/log.sh          (no dependencies)
    ↑
lib/platform.sh     (no dependencies)
    ↑
lib/fs.sh           depends on: log.sh
    ↑
lib/config.sh       depends on: log.sh
    ↑
lib/common.sh       depends on: log.sh, platform.sh, fs.sh (facade)
    ↑
lib/validate.sh     depends on: log.sh (from Task 01)
    ↑
lib/deps.sh         depends on: log.sh, config.sh, platform.sh
    ↑
lib/backup.sh       depends on: log.sh, fs.sh, config.sh
    ↑
lib/conflicts.sh    depends on: log.sh, fs.sh, config.sh
    ↑
lib/deploy.sh       depends on: log.sh, fs.sh, config.sh, conflicts.sh
    ↑
lib/verify.sh       depends on: log.sh, config.sh
```

### 4. Create Central Initialization Module

Create `lib/init.sh` for simplified initialization:

```bash
#!/usr/bin/env bash
# =================================================================
# lib/init.sh - Central module initialization
# =================================================================
# Usage: source lib/init.sh
# This sources all library modules in the correct order.
# Individual modules can still be sourced directly if needed.
# =================================================================

[[ -n "${_DOTFILES_INIT_LOADED:-}" ]] && return 0
_DOTFILES_INIT_LOADED=1

DOTFILES_LIB_DIR="${BASH_SOURCE%/*}"

# Core modules (no dependencies)
source "$DOTFILES_LIB_DIR/log.sh"
source "$DOTFILES_LIB_DIR/platform.sh"

# Filesystem utilities
source "$DOTFILES_LIB_DIR/fs.sh"

# Configuration
source "$DOTFILES_LIB_DIR/config.sh"

# Common facade (for backward compatibility)
source "$DOTFILES_LIB_DIR/common.sh"

# Feature modules
source "$DOTFILES_LIB_DIR/backup.sh"
source "$DOTFILES_LIB_DIR/conflicts.sh"
source "$DOTFILES_LIB_DIR/deploy.sh"
source "$DOTFILES_LIB_DIR/deps.sh"
source "$DOTFILES_LIB_DIR/verify.sh"

# Optional: validation helpers (from Task 01)
[[ -f "$DOTFILES_LIB_DIR/validate.sh" ]] && source "$DOTFILES_LIB_DIR/validate.sh"
```

### 5. Add Dependency Validation (Optional)

For stricter validation, add checks:

```bash
# In lib/deploy.sh (after guard)

# Validate dependencies are loaded
_require_module() {
    local module="$1"
    local guard_var="_DOTFILES_${module^^}_LOADED"
    if [[ -z "${!guard_var:-}" ]]; then
        echo "ERROR: Module '$module' is required but not loaded" >&2
        echo "Source lib/init.sh or source lib/$module.sh first" >&2
        return 1
    fi
}

_require_module "log" || return 1
_require_module "fs" || return 1
_require_module "config" || return 1
```

This is optional but provides clear error messages if dependencies are missing.

### 6. Update Entry Points

Simplify `install.sh`:

**Before:**
```bash
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/deploy.sh"
source "$SCRIPT_DIR/lib/deps.sh"
source "$SCRIPT_DIR/lib/backup.sh"
source "$SCRIPT_DIR/lib/conflicts.sh"
source "$SCRIPT_DIR/lib/verify.sh"
```

**After:**
```bash
source "$SCRIPT_DIR/lib/init.sh"
```

Update similarly:
- `validate.sh`
- Any other entry point scripts

### 7. Update Tests

Tests may need adjustment:

```bash
# In tests/helpers.sh

init_test_env() {
    local modules="$1"

    # Source full library
    source "$DOTFILES_DIR/lib/init.sh"

    # Or source specific modules for focused testing
    # source "$DOTFILES_DIR/lib/log.sh"
    # source "$DOTFILES_DIR/lib/config.sh"
}
```

### 8. Handle Circular Dependencies

If any circular dependencies exist, they must be resolved:

1. **Identify**: Run `grep -r "source.*lib/" lib/` and build graph
2. **Break cycles**: Extract shared code to a lower-level module
3. **Document**: Note any intentional shared dependencies

Example of breaking a cycle:
```
# If A depends on B and B depends on A:
# Extract shared functionality to C
# A depends on C
# B depends on C
```

## Files to Create/Modify
- `lib/init.sh` (CREATE - central initialization)
- `lib/log.sh` (MODIFY - add guard)
- `lib/platform.sh` (MODIFY - add guard)
- `lib/fs.sh` (MODIFY - add guard, declare deps)
- `lib/config.sh` (MODIFY - add guard, declare deps)
- `lib/common.sh` (MODIFY - add guard, simplify)
- `lib/deploy.sh` (MODIFY - add guard, declare deps)
- `lib/deps.sh` (MODIFY - add guard, declare deps)
- `lib/backup.sh` (MODIFY - add guard, declare deps)
- `lib/conflicts.sh` (MODIFY - add guard, declare deps)
- `lib/verify.sh` (MODIFY - add guard, declare deps)
- `install.sh` (MODIFY - use init.sh)
- `validate.sh` (MODIFY - use init.sh)
- `tests/helpers.sh` (MODIFY - update initialization)

## Module Template

Use this template when adding guards:

```bash
#!/usr/bin/env bash
# =================================================================
# lib/MODULE_NAME.sh - Brief description
# =================================================================
# Dependencies: list, of, dependencies
# Provides: function1, function2, function3
# =================================================================

# Source guard - prevent multiple loading
[[ -n "${_DOTFILES_MODULENAME_LOADED:-}" ]] && return 0
_DOTFILES_MODULENAME_LOADED=1

# Source dependencies
source "${BASH_SOURCE%/*}/dependency1.sh"
source "${BASH_SOURCE%/*}/dependency2.sh"

# =================================================================
# Module implementation
# =================================================================

function1() {
    # ...
}

function2() {
    # ...
}
```

## Testing
```bash
# Test that double-sourcing doesn't cause issues
source lib/init.sh
source lib/init.sh  # Should be no-op
source lib/deploy.sh  # Should be no-op (already loaded)

# Test individual module loading
bash -c 'source lib/deploy.sh && echo "deploy loaded successfully"'

# Test that dependencies are checked (if validation added)
bash -c 'source lib/deploy.sh'  # Should error if deps not met

# Run all tests
./tests/run_tests.sh

# Verify no circular dependencies
# (manual inspection or write a script to parse sources)
```

## Success Criteria
- [ ] All lib/*.sh files have source guards
- [ ] All lib/*.sh files document their dependencies in header
- [ ] `lib/init.sh` created and sources all modules correctly
- [ ] `install.sh` simplified to use `lib/init.sh`
- [ ] `validate.sh` simplified to use `lib/init.sh`
- [ ] No circular dependencies exist
- [ ] Double-sourcing any module is safe (no errors, no side effects)
- [ ] All tests pass
- [ ] Dependency graph documented (in code comments or separate doc)
