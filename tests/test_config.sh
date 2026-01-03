#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Tests for config module (lib/config.sh)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/helpers.sh
source "$SCRIPT_DIR/helpers.sh"

# Source config.sh (it now sources log.sh itself)
# Reset state first to avoid auto-init issues
_CONFIG_INITIALIZED=false
PACKAGES=()
BACKUP_FILES=()
VERIFY_SYMLINKS=()

# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/../lib/config.sh"

# =============================================================================
# Test functions
# =============================================================================

test_validate_config_entry_accepts_valid() {
    local result
    result=$(validate_config_entry "pkg:/path/backup:/path/verify" 2>&1)
    local exit_code=$?
    assert "Expected valid entry to pass" test "$exit_code" -eq 0
}

test_validate_config_entry_rejects_missing_colon() {
    local result
    result=$(validate_config_entry "pkg:/path" 2>&1)
    local exit_code=$?
    assert "Expected missing colon to fail" test "$exit_code" -ne 0
    assert_contains "$result" "expected pkg:backup:verify"
}

test_validate_config_entry_rejects_too_many_colons() {
    local result
    result=$(validate_config_entry "pkg:/path:/verify:extra" 2>&1)
    local exit_code=$?
    assert "Expected extra colon to fail" test "$exit_code" -ne 0
}

test_validate_config_entry_rejects_empty_package() {
    local result
    result=$(validate_config_entry ":/path:/verify" 2>&1)
    local exit_code=$?
    assert "Expected empty package to fail" test "$exit_code" -ne 0
    assert_contains "$result" "empty package name"
}

test_validate_config_entry_rejects_empty_backup() {
    local result
    result=$(validate_config_entry "pkg::/verify" 2>&1)
    local exit_code=$?
    assert "Expected empty backup to fail" test "$exit_code" -ne 0
    assert_contains "$result" "empty backup path"
}

test_validate_config_entry_rejects_empty_verify() {
    local result
    result=$(validate_config_entry "pkg:/path:" 2>&1)
    local exit_code=$?
    assert "Expected empty verify to fail" test "$exit_code" -ne 0
    assert_contains "$result" "empty verify path"
}

# =============================================================================
# Run all tests
# =============================================================================

# Simple tests - no setup/teardown needed
for test_func in $(declare -F | awk '{print $3}' | grep '^test_'); do
    if output=$("$test_func" 2>&1); then
        echo "PASS: $test_func"
    else
        echo "FAIL: $test_func"
        [[ -n "$output" ]] && echo "$output"
    fi
done
