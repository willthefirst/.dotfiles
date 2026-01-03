# Task: Standardize Test Files to Unified Framework

## Branch Name
`refactor/standardize-tests`

## Problem Statement
Test files use inconsistent patterns - some use the `run_all_tests` framework, others have custom test runners. This creates maintenance burden and confusion.

### Current State

**Pattern 1 - Modern (uses `run_all_tests`):**
- `tests/test_backup.sh:71`
- `tests/test_deploy.sh:97`
- `tests/test_deps.sh:233`
- `tests/test_fs.sh:92`
- `tests/test_verify.sh:72`

**Pattern 2 - Custom runner:**
- `tests/test_config.sh:76-83` - implements own loop
- `tests/test_consistency.sh:95-105` - custom test runner

**Example of custom runner in `test_config.sh:76-83`:**
```bash
for test_func in $(declare -F | awk '{print $3}' | grep '^test_'); do
    if output=$("$test_func" 2>&1); then
        echo "PASS: $test_func"
    else
        echo "FAIL: $test_func"
        [[ -n "$output" ]] && echo "$output"
    fi
done
```

**Pattern 3 - Mixed setup patterns:**
Different tests define `setup()` and `teardown()` differently:

```bash
# test_backup.sh:13
setup() { setup_test_env true; }

# test_deps.sh:13-21
setup() {
    setup_test_env true
    deps_dry_run_enable
}
teardown() {
    deps_dry_run_disable
    teardown_test_env
}
```

### Issues
1. Inconsistent test output format
2. Custom runners may miss edge cases handled by framework
3. Harder to add new tests - unclear which pattern to follow
4. Setup/teardown behavior varies between test files

## Desired Outcome
All test files use the unified `run_all_tests` framework from `tests/framework.sh` with consistent setup/teardown patterns.

## Implementation Steps

### 1. Understand the framework
Read `tests/framework.sh` to understand:
- How `run_all_tests` discovers and runs tests
- Expected `setup()` and `teardown()` function signatures
- Output format expectations

### 2. Fix `tests/test_config.sh`

**Current (lines 76-83):**
```bash
for test_func in $(declare -F | awk '{print $3}' | grep '^test_'); do
    if output=$("$test_func" 2>&1); then
        echo "PASS: $test_func"
    else
        echo "FAIL: $test_func"
        [[ -n "$output" ]] && echo "$output"
    fi
done
```

**Replace with:**
```bash
run_all_tests
```

Ensure the file:
- Sources `tests/framework.sh` (or `tests/helpers.sh` which sources it)
- Defines `setup()` and `teardown()` if needed
- Has test functions named `test_*`

### 3. Fix `tests/test_consistency.sh`

Review lines 95-105 and replace custom runner with `run_all_tests`.

### 4. Standardize setup/teardown patterns

Create consistent pattern across all test files:

```bash
#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

# Initialize test environment for specific module(s)
init_test_env "module_name"

# Setup runs before each test
setup() {
    setup_test_env true  # true = create fresh test directory
}

# Teardown runs after each test
teardown() {
    teardown_test_env
}

# Test functions
test_something() {
    # ... test code ...
}

test_another_thing() {
    # ... test code ...
}

# Run all tests using framework
run_all_tests
```

### 5. Review each test file

Go through each file in `tests/` and verify it follows the pattern:

| File | Status | Action Needed |
|------|--------|---------------|
| `test_backup.sh` | Modern | Verify consistency |
| `test_config.sh` | Custom | Convert to framework |
| `test_conflicts.sh` | Modern | Verify consistency |
| `test_consistency.sh` | Custom | Convert to framework |
| `test_deploy.sh` | Modern | Verify consistency |
| `test_deps.sh` | Modern | Verify consistency |
| `test_fs.sh` | Modern | Verify consistency |
| `test_verify.sh` | Modern | Verify consistency |

### 6. Update test runner if needed

Check `tests/test_runner.sh` or `tests/run_tests.sh`:
- Ensure it works with the standardized format
- Verify test counting/reporting works correctly

### 7. Document the pattern

Add a comment block at the top of `tests/framework.sh` or create `tests/README.md` explaining:
- How to write a new test file
- Required structure (setup, teardown, test_* functions)
- How to run tests

## Files to Modify
- `tests/test_config.sh` (MODIFY - replace custom runner)
- `tests/test_consistency.sh` (MODIFY - replace custom runner)
- `tests/framework.sh` (VERIFY - may need documentation)
- Other `tests/test_*.sh` files (VERIFY - ensure consistency)

## Testing
```bash
# Run all tests and verify they all execute
./tests/run_tests.sh

# Run individual test files to verify they work standalone
./tests/test_config.sh
./tests/test_consistency.sh

# Verify test count matches expected
./tests/run_tests.sh 2>&1 | grep -E "PASS|FAIL" | wc -l
```

## Success Criteria
- [ ] All test files use `run_all_tests` from framework
- [ ] No custom test runner loops in any test file
- [ ] Consistent setup/teardown pattern across all tests
- [ ] All tests pass after standardization
- [ ] Test output format is consistent across all files
- [ ] New test template is documented (optional)
