# Task: Standardize Error Handling Conventions

## Branch Name
`refactor/error-handling`

## Problem Statement
Error handling is inconsistent across the codebase. Some functions log errors, some don't, and naming conventions aren't followed consistently.

### Current Patterns Found

**Pattern 1 - Check functions (return 0/1, no logging):**
```bash
# lib/fs.sh:17-18
file_or_link_exists() {
    [[ -e "$1" || -L "$1" ]]
}
```

**Pattern 2 - Action functions (log before return):**
```bash
# lib/deploy.sh:27-29
create_directories() {
    if ! mkdir -p "$HOME/.config"; then
        log_error "Failed to create ~/.config"
        return 1
    fi
}
```

**Pattern 3 - Validation (double logging):**
```bash
# validate.sh:28-39
check() {
    local desc="$1"
    shift
    if "$@" > /dev/null 2>&1; then
        log_ok "$desc"
        return 0
    else
        log_error "$desc"
        return 1
    fi
}
```

### Documented Convention (lib/common.sh:16-18)
```bash
# - Check functions: is_*, has_*, check_* (return 0/1, no logging)
# - Action functions: verb_noun (e.g., create_backup, deploy_packages)
```

### Issues
1. Convention exists but isn't enforced
2. Some check functions log (violating convention)
3. Some action functions don't log errors
4. Naming is inconsistent (`has_command` vs `require_command`)
5. No clear guidance on when to use which pattern

## Desired Outcome
1. Document clear conventions
2. Audit all functions for compliance
3. Fix violations
4. Add linting to catch future violations

## Implementation Steps

### 1. Document Conventions

Create or update `lib/README.md` or add to `lib/common.sh`:

```bash
# =================================================================
# Function Conventions
# =================================================================
#
# 1. CHECK FUNCTIONS (Predicates)
#    - Names: is_*, has_*, can_*
#    - Behavior: Return 0 (true) or 1 (false)
#    - Logging: NEVER log - let caller decide
#    - Side effects: None
#    - Examples:
#      is_macos()         - returns 0 if on macOS
#      has_command "git"  - returns 0 if git is installed
#      can_write_to "/path" - returns 0 if path is writable
#
# 2. VALIDATION FUNCTIONS (User-facing checks)
#    - Names: require_*, validate_*, check_* (when logging)
#    - Behavior: Return 0 (success) or 1 (failure)
#    - Logging: Log descriptive message on failure
#    - Examples:
#      require_cmd "git"  - logs error and returns 1 if missing
#      validate_config()  - logs errors for each invalid entry
#
# 3. ACTION FUNCTIONS (Do something)
#    - Names: verb_noun (create_backup, deploy_package, install_deps)
#    - Behavior: Perform action, return 0 (success) or 1 (failure)
#    - Logging: Log errors on failure, optionally log progress
#    - Examples:
#      create_backup()    - creates backup, logs error on failure
#      deploy_packages()  - deploys packages, logs progress
#
# 4. GETTER FUNCTIONS (Return data)
#    - Names: get_*
#    - Behavior: Echo result to stdout, return 0/1 for success/failure
#    - Logging: NEVER log to stdout (would corrupt return value)
#    - Examples:
#      get_all_packages() - echoes package list
#      get_platform()     - echoes "macos" or "linux"
#
# =================================================================
```

### 2. Audit All Functions

Create a checklist of all functions and their compliance:

| File | Function | Type | Compliant? | Issue |
|------|----------|------|------------|-------|
| lib/fs.sh | file_or_link_exists | check | ✓ | - |
| lib/fs.sh | is_symlink | check | ✓ | - |
| lib/common.sh | require_command | validation | ? | Check if logs |
| lib/deps.sh | has_command | check | ? | Name suggests check, verify no logging |
| lib/deploy.sh | create_directories | action | ✓ | - |
| ... | ... | ... | ... | ... |

Run this to find all functions:
```bash
grep -rn "^[a-z_]*() {" lib/ --include="*.sh"
```

### 3. Fix Naming Violations

**Functions with wrong naming pattern:**

```bash
# Should be is_* or has_*
require_command()  # If it just checks, rename to has_command
                   # If it logs, keep as require_command

# Consolidate duplicates
has_command()      # In deps.sh
require_command()  # In common.sh
require_cmd()      # In validate.sh (Task 01)
# → Pick one check (has_command) and one validation (require_cmd)
```

### 4. Fix Logging Violations

**Check functions that log (shouldn't):**
```bash
# Find any is_*/has_*/can_* that call log_*
grep -A5 "^is_\|^has_\|^can_" lib/*.sh | grep "log_"
```

**Action functions that don't log errors (should):**
Review each action function and ensure it logs meaningful errors.

### 5. Create Standardized Error Messages

Define error message format:

```bash
# Error messages should include:
# 1. What failed
# 2. Why it might have failed (if known)
# 3. How to fix (if known)

# Good:
log_error "Failed to create directory: $dir (permission denied?)"
log_error "Package '$pkg' not found. Run './install.sh' to see available packages."

# Bad:
log_error "Error"
log_error "Failed"
```

### 6. Update Functions for Compliance

**Example fix - ensure action function logs:**

Before:
```bash
# lib/backup.sh
create_backup() {
    local src="$1"
    local dest="$2"
    cp -r "$src" "$dest"  # Silent failure
}
```

After:
```bash
# lib/backup.sh
create_backup() {
    local src="$1"
    local dest="$2"
    if ! cp -r "$src" "$dest"; then
        log_error "Failed to create backup: $src → $dest"
        return 1
    fi
}
```

**Example fix - check function shouldn't log:**

Before:
```bash
# lib/deps.sh
has_command() {
    if ! command -v "$1" &>/dev/null; then
        log_warn "Command not found: $1"  # Shouldn't log!
        return 1
    fi
    return 0
}
```

After:
```bash
# lib/deps.sh
has_command() {
    command -v "$1" &>/dev/null
}

# Separate validation function if logging needed:
require_command() {
    local cmd="$1"
    if ! has_command "$cmd"; then
        log_error "Required command not found: $cmd"
        return 1
    fi
}
```

### 7. Update Lint Script

Enhance `scripts/lint-conventions.sh` (if it exists) or create it:

```bash
#!/usr/bin/env bash
# Lint for function convention violations

errors=0

# Check functions should not log
echo "Checking: is_*/has_*/can_* functions should not log..."
while IFS= read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    func=$(echo "$line" | grep -oP '(is_|has_|can_)[a-z_]+')

    # Get function body and check for log calls
    if grep -A20 "^${func}()" "$file" | grep -q "log_"; then
        echo "ERROR: $file: $func() is a check function but contains logging"
        ((errors++))
    fi
done < <(grep -rn "^is_\|^has_\|^can_" lib/*.sh)

# Get functions should not log to stdout (would corrupt output)
echo "Checking: get_* functions should not use log_info/log_step..."
# ... similar check ...

# Action functions should handle errors
echo "Checking: action functions should log errors..."
# ... check for functions with commands that could fail ...

if [[ $errors -gt 0 ]]; then
    echo "Found $errors convention violations"
    exit 1
fi

echo "All conventions checks passed"
```

### 8. Add to CI/Validation

Update `validate.sh` or CI to run lint checks:

```bash
# In validate.sh
check "Lint conventions" scripts/lint-conventions.sh
```

## Files to Modify
- `lib/common.sh` (MODIFY - add/update convention documentation)
- `lib/fs.sh` (VERIFY - check compliance)
- `lib/deps.sh` (MODIFY - fix has_command if needed)
- `lib/deploy.sh` (VERIFY - check error logging)
- `lib/backup.sh` (MODIFY - add error logging if missing)
- `lib/config.sh` (VERIFY - check compliance)
- `lib/conflicts.sh` (VERIFY - check compliance)
- `lib/verify.sh` (VERIFY - check compliance)
- `scripts/lint-conventions.sh` (CREATE or MODIFY)
- `validate.sh` (MODIFY - add lint check)

## Audit Template

Use this to audit each file:

```markdown
### lib/FILENAME.sh

| Function | Type | Logs? | Compliant? | Action |
|----------|------|-------|------------|--------|
| func1 | check | no | ✓ | - |
| func2 | action | yes | ✓ | - |
| func3 | check | yes | ✗ | Remove logging |
| func4 | action | no | ✗ | Add error logging |
```

## Testing
```bash
# Run lint check
./scripts/lint-conventions.sh

# Run validation
./validate.sh

# Run tests (ensure refactoring didn't break anything)
./tests/run_tests.sh

# Manual verification - check a few functions
grep -A10 "^has_command()" lib/deps.sh  # Should not contain log_
grep -A10 "^create_backup()" lib/backup.sh  # Should contain log_error on failure
```

## Success Criteria
- [ ] Conventions documented in `lib/common.sh` or `lib/README.md`
- [ ] All check functions (is_*, has_*, can_*) don't log
- [ ] All action functions log meaningful errors on failure
- [ ] Duplicate functions consolidated (has_command vs require_command)
- [ ] Lint script created and catches violations
- [ ] `validate.sh` runs lint check
- [ ] All tests pass
- [ ] No convention violations in codebase
