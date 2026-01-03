# Task: Extract Validation Helpers to Shared Module

## Branch Name
`refactor/extract-validation-helpers`

## Problem Statement
Validation helper functions are duplicated between `validate.sh` and `lib/common.sh`, with inconsistent naming and no shared module.

### Current State

**In `validate.sh` (lines 28-78):**
```bash
check()        # runs command and logs result (lines 28-39)
check_warn()   # runs command, logs warning on fail (lines 43-51)
check_file()   # checks if file exists (lines 55-66)
require_cmd()  # checks if command is available (lines 70-78)
```

**In `lib/common.sh` (line 36):**
```bash
require_command()  # identical logic to require_cmd()
```

### Issues
1. `require_command()` and `require_cmd()` do the same thing with different names
2. Validation functions in `validate.sh` are not reusable by other scripts
3. No single source of truth for validation logic
4. If validation logic needs to change, multiple places must be updated

## Desired Outcome
Create `lib/validate.sh` module containing unified validation functions that can be used by both `validate.sh` and `install.sh` (and any future scripts).

## Implementation Steps

1. **Create `lib/validate.sh`** with the following functions:
   - `check()` - run command and log pass/fail result
   - `check_warn()` - run command, log warning (not error) on failure
   - `check_file()` - verify file exists
   - `require_cmd()` - verify command is available (keep this name, it's shorter)

2. **Update `validate.sh`**:
   - Remove the local function definitions (lines 28-78)
   - Source the new `lib/validate.sh` module
   - Ensure all existing validation checks still work

3. **Update `lib/common.sh`**:
   - Remove `require_command()` function (line 36)
   - Source `lib/validate.sh` if needed, OR just use `require_cmd()` where needed

4. **Search for other usages**:
   - Run `grep -r "require_command\|require_cmd" .` to find all usages
   - Update any callers to use the unified function name

5. **Update tests**:
   - Ensure `tests/test_*.sh` files work with the refactored code
   - Add tests for the new `lib/validate.sh` module if appropriate

## Files to Modify
- `lib/validate.sh` (CREATE)
- `validate.sh` (MODIFY - remove duplicate functions, add source)
- `lib/common.sh` (MODIFY - remove require_command)
- Any files that call `require_command()` (MODIFY - rename to require_cmd)

## Testing
```bash
# Run the validation script
./validate.sh

# Run all tests
./tests/run_tests.sh

# Verify no broken references
grep -r "require_command" . --include="*.sh"
```

## Success Criteria
- [ ] `lib/validate.sh` exists with all validation helpers
- [ ] `validate.sh` sources the new module and works correctly
- [ ] No duplicate `require_command`/`require_cmd` functions exist
- [ ] All tests pass
- [ ] `./validate.sh` runs successfully
