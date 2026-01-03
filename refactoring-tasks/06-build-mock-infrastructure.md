# Task: Build Proper Mock Infrastructure for Tests

## Branch Name
`refactor/test-mock-infrastructure`

## Problem Statement
The current mock infrastructure in `tests/mocks.sh` is minimal (34 lines) and lacks essential testing capabilities. Tests cannot properly isolate behavior or verify function calls.

### Current State in `tests/mocks.sh`
Only provides:
- `create_mock_package()` - creates fake package directory
- `create_mock_package_with_content()` - same with file content

### Missing Capabilities
1. **Command mocking** - can't override `stow`, `brew`, `git`, etc.
2. **Function spying** - can't verify functions were called
3. **Call verification** - can't check arguments passed to mocked functions
4. **Invocation counting** - can't verify how many times something was called

### Current Testing Workaround
Tests use global `DRY_RUN` variable in production code:
```bash
# In tests/test_deps.sh
setup() {
    setup_test_env true
    deps_dry_run_enable  # Sets global DRY_RUN=true
}
```

This pollutes production code with test concerns.

## Desired Outcome
Comprehensive mock infrastructure that enables:
- Mocking any command or function
- Recording all calls with arguments
- Verifying specific calls were made
- Counting invocations
- Stubbing return values

## Implementation Steps

### 1. Design the Mock Framework

Core concepts:
- **Mock**: Replaces a function/command with a fake
- **Spy**: Records calls while optionally executing real function
- **Stub**: Returns predetermined values
- **Call Log**: Records all mock invocations

### 2. Implement Core Mock Functions in `tests/mocks.sh`

```bash
#!/usr/bin/env bash
# Test mocking infrastructure

# Global call log file
MOCK_CALL_LOG=""

# Initialize mock system
mock_init() {
    MOCK_CALL_LOG=$(mktemp)
    echo "" > "$MOCK_CALL_LOG"
}

# Cleanup mock system
mock_cleanup() {
    [[ -f "$MOCK_CALL_LOG" ]] && rm -f "$MOCK_CALL_LOG"
    MOCK_CALL_LOG=""
}

# Record a function call
# Usage: mock_record <function_name> [args...]
mock_record() {
    local func_name="$1"
    shift
    echo "${func_name}|$*" >> "$MOCK_CALL_LOG"
}

# Create a mock function that records calls and returns success
# Usage: mock_function <function_name> [return_value]
mock_function() {
    local func_name="$1"
    local return_val="${2:-0}"

    eval "${func_name}() {
        mock_record '${func_name}' \"\$@\"
        return ${return_val}
    }"
}

# Create a mock that outputs specific text
# Usage: mock_function_output <function_name> <output>
mock_function_output() {
    local func_name="$1"
    local output="$2"

    eval "${func_name}() {
        mock_record '${func_name}' \"\$@\"
        echo '${output}'
        return 0
    }"
}

# Create a mock that fails
# Usage: mock_function_fail <function_name> [error_message]
mock_function_fail() {
    local func_name="$1"
    local error_msg="${2:-Mock failure}"

    eval "${func_name}() {
        mock_record '${func_name}' \"\$@\"
        echo '${error_msg}' >&2
        return 1
    }"
}

# Verify a function was called
# Usage: mock_verify_called <function_name>
# Returns: 0 if called, 1 if not
mock_verify_called() {
    local func_name="$1"
    grep -q "^${func_name}|" "$MOCK_CALL_LOG"
}

# Verify a function was called with specific arguments
# Usage: mock_verify_called_with <function_name> <expected_args>
mock_verify_called_with() {
    local func_name="$1"
    local expected_args="$2"
    grep -q "^${func_name}|${expected_args}$" "$MOCK_CALL_LOG"
}

# Get the number of times a function was called
# Usage: mock_call_count <function_name>
mock_call_count() {
    local func_name="$1"
    grep -c "^${func_name}|" "$MOCK_CALL_LOG" || echo "0"
}

# Get all calls to a function (for debugging)
# Usage: mock_get_calls <function_name>
mock_get_calls() {
    local func_name="$1"
    grep "^${func_name}|" "$MOCK_CALL_LOG" | sed "s/^${func_name}|//"
}

# Verify a function was NOT called
# Usage: mock_verify_not_called <function_name>
mock_verify_not_called() {
    local func_name="$1"
    ! grep -q "^${func_name}|" "$MOCK_CALL_LOG"
}

# Clear call history (useful between tests)
mock_reset() {
    echo "" > "$MOCK_CALL_LOG"
}

# ============================================
# Package/Directory Mocks (existing, enhanced)
# ============================================

# Create a mock package directory structure
create_mock_package() {
    local pkg_name="$1"
    local pkg_dir="$TEST_PACKAGES_DIR/$pkg_name"

    mkdir -p "$pkg_dir"
    echo "$pkg_dir"
}

# Create mock package with specific file content
create_mock_package_with_content() {
    local pkg_name="$1"
    local file_path="$2"
    local content="$3"

    local pkg_dir
    pkg_dir=$(create_mock_package "$pkg_name")

    local full_path="$pkg_dir/$file_path"
    mkdir -p "$(dirname "$full_path")"
    echo "$content" > "$full_path"

    echo "$pkg_dir"
}

# Create mock stow package (with proper structure for stow)
create_mock_stow_package() {
    local pkg_name="$1"
    shift
    local files=("$@")

    local pkg_dir
    pkg_dir=$(create_mock_package "$pkg_name")

    for file in "${files[@]}"; do
        local full_path="$pkg_dir/$file"
        mkdir -p "$(dirname "$full_path")"
        touch "$full_path"
    done

    echo "$pkg_dir"
}
```

### 3. Add Common Mock Presets

```bash
# ============================================
# Common Mock Presets
# ============================================

# Mock stow command
mock_stow() {
    mock_function "stow"
}

# Mock stow to fail
mock_stow_fail() {
    mock_function_fail "stow" "stow: conflict detected"
}

# Mock brew command
mock_brew() {
    mock_function "brew"
}

# Mock apt-get command
mock_apt_get() {
    mock_function "apt-get"
}

# Mock sudo to just run the command without elevation
mock_sudo() {
    sudo() {
        mock_record "sudo" "$@"
        # Run the command without sudo
        "$@"
    }
}

# Mock curl to return fake data
# Usage: mock_curl_response <response_data>
mock_curl_response() {
    local response="$1"
    curl() {
        mock_record "curl" "$@"
        echo "$response"
    }
}

# Mock git command
mock_git() {
    mock_function "git"
}

# Mock pkg_install for dependency tests
mock_pkg_install() {
    mock_function "pkg_install"
}
```

### 4. Update Test Framework Integration

In `tests/helpers.sh` or `tests/framework.sh`, integrate mock lifecycle:

```bash
# Enhanced setup_test_env
setup_test_env() {
    local create_dirs="${1:-true}"

    # Initialize mocks
    mock_init

    # ... existing setup code ...
}

# Enhanced teardown_test_env
teardown_test_env() {
    # Cleanup mocks
    mock_cleanup

    # ... existing teardown code ...
}
```

### 5. Update Existing Tests to Use New Mocks

**Example: Update `tests/test_deps.sh`**

Before:
```bash
setup() {
    setup_test_env true
    deps_dry_run_enable
}

test_install_package_deps() {
    # Test runs with DRY_RUN=true globally
    install_package_deps "mypackage"
    # ... assertions ...
}
```

After:
```bash
setup() {
    setup_test_env true
    mock_pkg_install  # Mock the package installer
}

test_install_package_deps() {
    install_package_deps "mypackage"

    # Verify pkg_install was called
    mock_verify_called "pkg_install"

    # Verify it was called with expected package
    mock_verify_called_with "pkg_install" "expected-dep"
}
```

### 6. Add Assertion Helpers

```bash
# ============================================
# Test Assertions for Mocks
# ============================================

# Assert function was called (fails test if not)
assert_called() {
    local func_name="$1"
    if ! mock_verify_called "$func_name"; then
        echo "ASSERTION FAILED: Expected $func_name to be called"
        mock_get_calls "$func_name"
        return 1
    fi
}

# Assert function was called with args
assert_called_with() {
    local func_name="$1"
    local expected_args="$2"
    if ! mock_verify_called_with "$func_name" "$expected_args"; then
        echo "ASSERTION FAILED: Expected $func_name to be called with: $expected_args"
        echo "Actual calls:"
        mock_get_calls "$func_name"
        return 1
    fi
}

# Assert function was called N times
assert_call_count() {
    local func_name="$1"
    local expected_count="$2"
    local actual_count
    actual_count=$(mock_call_count "$func_name")
    if [[ "$actual_count" -ne "$expected_count" ]]; then
        echo "ASSERTION FAILED: Expected $func_name to be called $expected_count times, was called $actual_count times"
        return 1
    fi
}

# Assert function was NOT called
assert_not_called() {
    local func_name="$1"
    if ! mock_verify_not_called "$func_name"; then
        echo "ASSERTION FAILED: Expected $func_name NOT to be called"
        echo "But it was called with:"
        mock_get_calls "$func_name"
        return 1
    fi
}
```

### 7. Document Mock Usage

Add documentation block at top of `tests/mocks.sh`:

```bash
# =================================================================
# Mock Infrastructure for Bash Testing
# =================================================================
#
# Usage:
#   1. Call mock_init() in test setup (done automatically by setup_test_env)
#   2. Create mocks: mock_function "function_name"
#   3. Run code under test
#   4. Verify: assert_called "function_name"
#   5. Cleanup happens automatically in teardown
#
# Examples:
#
#   # Mock a function to succeed
#   mock_function "stow"
#   deploy_package "mypackage"
#   assert_called "stow"
#
#   # Mock a function to fail
#   mock_function_fail "brew" "Package not found"
#   result=$(install_dep "nonexistent" 2>&1) || true
#   assert_called "brew"
#
#   # Verify specific arguments
#   mock_function "pkg_install"
#   install_package_deps "git"
#   assert_called_with "pkg_install" "lazygit"
#
#   # Check call count
#   mock_function "log_step"
#   some_function_that_logs
#   assert_call_count "log_step" 3
#
# =================================================================
```

## Files to Create/Modify
- `tests/mocks.sh` (MAJOR REWRITE)
- `tests/helpers.sh` (MODIFY - integrate mock lifecycle)
- `tests/framework.sh` (MODIFY - if needed for integration)
- `tests/test_deps.sh` (MODIFY - use new mocks)
- `tests/test_deploy.sh` (MODIFY - use new mocks)
- Other test files as needed

## Testing
```bash
# Test the mock infrastructure itself
source tests/mocks.sh
mock_init

# Test mock creation
mock_function "my_test_func"
my_test_func "arg1" "arg2"
mock_verify_called "my_test_func" && echo "PASS: verify_called"
mock_verify_called_with "my_test_func" "arg1 arg2" && echo "PASS: verify_called_with"

mock_cleanup

# Run all tests
./tests/run_tests.sh
```

## Success Criteria
- [ ] `tests/mocks.sh` provides comprehensive mocking API
- [ ] Can mock any function and verify it was called
- [ ] Can verify functions were called with specific arguments
- [ ] Can count function invocations
- [ ] Mock lifecycle integrated with test setup/teardown
- [ ] At least one existing test refactored to use new mocks
- [ ] Documentation explains mock usage
- [ ] All existing tests still pass
- [ ] No production code changes needed (remove DRY_RUN in separate task)
