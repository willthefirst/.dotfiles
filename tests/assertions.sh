#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Test assertions library
# =============================================================================
# This module provides assertion functions for tests:
#   - assert, assert_fails, assert_contains
#   - assert_symlink, assert_file_exists, assert_dir_exists
#   - assert_permissions
# =============================================================================

# =============================================================================
# Basic assertions
# =============================================================================

# Assert a condition is true
# Usage: assert "description" command [args...]
# Example: assert "directory exists" test -d "$path"
assert() {
    local msg="$1"
    shift
    if "$@"; then
        return 0
    fi
    echo "  $msg"
    return 1
}

# Assert a command fails (returns non-zero)
# Usage: assert_fails "description" command [args...]
# Example: assert_fails "file does not exist" test -f "$path"
assert_fails() {
    local msg="$1"
    shift
    if ! "$@"; then
        return 0
    fi
    echo "  $msg"
    return 1
}

# Assert output contains expected string
# Usage: assert_contains "$output" "expected"
assert_contains() {
    local output="$1"
    local expected="$2"
    if echo "$output" | grep -q "$expected"; then
        return 0
    fi
    echo "  Expected output to contain: $expected"
    return 1
}

# =============================================================================
# File system assertions
# =============================================================================

# Assert that a symlink exists and points to the expected target
# Usage: assert_symlink "/path/to/link" "/expected/target"
assert_symlink() {
    local link="$1"
    local expected="$2"

    if [[ ! -L "$link" ]]; then
        echo "FAIL: Expected symlink at $link"
        return 1
    fi

    local actual
    actual=$(resolve_link "$link")
    local expected_resolved
    expected_resolved=$(resolve_link "$expected")

    if [[ "$actual" != "$expected_resolved" ]]; then
        echo "FAIL: Symlink $link points to $actual, expected $expected_resolved"
        return 1
    fi
    return 0
}

# Assert a file exists (not a symlink)
# Usage: assert_file_exists "/path/to/file"
assert_file_exists() {
    local path="$1"
    if [[ -f "$path" && ! -L "$path" ]]; then
        return 0
    fi
    echo "FAIL: Expected regular file at $path"
    return 1
}

# Assert a directory exists
# Usage: assert_dir_exists "/path/to/dir"
assert_dir_exists() {
    local path="$1"
    if [[ -d "$path" ]]; then
        return 0
    fi
    echo "FAIL: Expected directory at $path"
    return 1
}

# =============================================================================
# Permission assertions
# =============================================================================

# Get file permissions in octal (portable across macOS and Linux)
# Usage: get_file_permissions "/path/to/file"
get_file_permissions() {
    local path="$1"
    if [[ "$(uname)" == "Darwin" ]]; then
        stat -f "%Lp" "$path"
    else
        stat -c "%a" "$path"
    fi
}

# Assert file has expected permissions
# Usage: assert_permissions "/path/to/file" "700"
assert_permissions() {
    local path="$1"
    local expected="$2"
    local actual
    actual=$(get_file_permissions "$path")
    if [[ "$actual" == "$expected" ]]; then
        return 0
    fi
    echo "  Expected permissions $expected on $path, got $actual"
    return 1
}
