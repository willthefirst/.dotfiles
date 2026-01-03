#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Tests for platform detection (lib/platform.sh)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/helpers.sh
source "$SCRIPT_DIR/helpers.sh"
init_test_env deps  # deps.sh has get_platform_suffix

# =============================================================================
# Platform detection tests
# =============================================================================

test_is_darwin_or_is_linux() {
    if is_macos || is_linux; then
        return 0
    fi
    echo "  Neither is_macos nor is_linux returned true"
    return 1
}

test_get_platform_suffix_returns_valid() {
    local suffix
    suffix=$(get_platform_suffix)
    if [[ "$suffix" == "darwin" || "$suffix" == "linux" ]]; then
        return 0
    fi
    echo "  Expected 'darwin' or 'linux', got: $suffix"
    return 1
}

test_is_macos_and_is_linux_mutually_exclusive() {
    local macos_result linux_result
    is_macos && macos_result=0 || macos_result=1
    is_linux && linux_result=0 || linux_result=1

    # Exactly one should be true (return 0)
    if [[ $macos_result -eq 0 && $linux_result -eq 1 ]] || \
       [[ $macos_result -eq 1 && $linux_result -eq 0 ]]; then
        return 0
    fi
    echo "  Expected exactly one of is_macos/is_linux to be true"
    return 1
}

# =============================================================================
# Run all tests
# =============================================================================
run_all_tests
