# Task: Refactor deps.sh to Separate Concerns and Enable Dependency Injection

## Branch Name
`refactor/deps-module-di`

## Problem Statement
`lib/deps.sh` (313 lines) has multiple responsibilities and uses global state for testing, making it hard to test and maintain.

### Current Issues

**1. Mixed Responsibilities (lines across file):**
- Package manager abstraction (lines 49-84)
- Utility helpers duplicated from common.sh (lines 105-117)
- Dependency file parsing (lines 122-149)
- Main installation logic (lines 155-227)
- Test-specific dry-run mode (lines 299-313)

**2. Global State for Testing:**
```bash
# lib/deps.sh:301
DRY_RUN=${DRY_RUN:-false}
```

Functions check this global instead of accepting it as a parameter:
- `install_package_deps()` checks `$DRY_RUN` (lines 188, 242)
- `install_single_dep()` checks `$DRY_RUN` (line 242)

**3. Duplicate Utility Functions:**
- `has_command()` at line 108 duplicates `require_command()` in `lib/common.sh:36`
- `ensure_dir()` is a generic utility that doesn't belong in deps module

**4. Tight Coupling:**
- Directly depends on globals: `DOTFILES_DIR`, `DRY_RUN`, `SETUP_PHASE`
- No way to mock package installation behavior

## Desired Outcome
1. Separate package manager concerns into `lib/pkg-manager.sh`
2. Move utility functions to appropriate modules
3. Enable dependency injection for testing (remove global DRY_RUN)
4. Keep `lib/deps.sh` focused on dependency resolution only

## Implementation Steps

### 1. Create `lib/pkg-manager.sh`
Extract package manager abstraction:
```bash
# Functions to move:
pkg_install()      # lines 49-84 - platform-specific package installation
is_macos()         # may already be in platform.sh
is_linux()         # may already be in platform.sh
```

This module handles the "how" of installing packages (brew vs apt).

### 2. Move utility functions

**Move `ensure_dir()` to `lib/fs.sh`:**
- This is a filesystem utility, not deps-specific
- Check if similar function already exists in fs.sh

**Remove `has_command()`:**
- Use `require_cmd()` from the validation module (Task 01)
- Or consolidate with existing `require_command()` in common.sh

### 3. Refactor for Dependency Injection

**Current pattern (bad):**
```bash
install_single_dep() {
    local dep="$1"
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would install: $dep"
        return 0
    fi
    pkg_install "$dep"
}
```

**New pattern (good) - Option A: Parameter injection:**
```bash
install_single_dep() {
    local dep="$1"
    local dry_run="${2:-false}"
    if [[ "$dry_run" == "true" ]]; then
        log_info "[DRY RUN] Would install: $dep"
        return 0
    fi
    pkg_install "$dep"
}
```

**New pattern (good) - Option B: Function override for testing:**
```bash
# In lib/deps.sh - define default implementation
: "${PKG_INSTALL_CMD:=pkg_install}"

install_single_dep() {
    local dep="$1"
    $PKG_INSTALL_CMD "$dep"
}

# In tests - override the function
PKG_INSTALL_CMD=mock_pkg_install
```

Choose Option A (parameter injection) for clarity.

### 4. Update `lib/deps.sh`

After refactoring, deps.sh should only contain:
- `read_deps_file()` - parse dependency files
- `get_package_deps()` - resolve dependencies for a package
- `install_package_deps()` - orchestrate installation (using injected pkg_install)

Remove:
- `DRY_RUN` global and related functions (`deps_dry_run_enable`, `deps_dry_run_disable`)
- `has_command()`, `ensure_dir()`
- Direct `pkg_install()` implementation (moved to pkg-manager.sh)

### 5. Update test infrastructure

**In `tests/test_deps.sh`:**
- Remove `deps_dry_run_enable`/`deps_dry_run_disable` calls
- Pass `dry_run=true` parameter to functions, OR
- Override `pkg_install` function in test setup

**Example test update:**
```bash
# Before
setup() {
    setup_test_env true
    deps_dry_run_enable  # Sets global
}

# After
setup() {
    setup_test_env true
}

test_install_deps() {
    # Option A: Pass parameter
    install_package_deps "mypackage" --dry-run

    # Option B: Override function
    pkg_install() { echo "MOCK: $@"; }
    install_package_deps "mypackage"
}
```

### 6. Update callers
Search for usages:
```bash
grep -r "DRY_RUN\|deps_dry_run" . --include="*.sh"
grep -r "has_command\|ensure_dir" . --include="*.sh"
```

## Files to Create/Modify
- `lib/pkg-manager.sh` (CREATE)
- `lib/deps.sh` (MODIFY - major refactor)
- `lib/fs.sh` (MODIFY - add ensure_dir if not present)
- `tests/test_deps.sh` (MODIFY - update for DI)
- `tests/helpers.sh` or `tests/mocks.sh` (MODIFY - add pkg_install mock)

## Testing
```bash
# Run deps tests
./tests/run_tests.sh test_deps.sh

# Run all tests
./tests/run_tests.sh

# Test actual installation (careful - installs real packages)
./install.sh --with-deps base
```

## Success Criteria
- [ ] `lib/pkg-manager.sh` exists with package manager logic
- [ ] `lib/deps.sh` is focused on dependency resolution only
- [ ] No global `DRY_RUN` variable in production code
- [ ] Tests use dependency injection instead of global state
- [ ] `ensure_dir()` moved to `lib/fs.sh`
- [ ] `has_command()` removed (use unified validation helper)
- [ ] All tests pass
- [ ] `install.sh --with-deps` works correctly
