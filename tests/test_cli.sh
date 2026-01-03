#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Tests for CLI argument parsing module (lib/cli.sh)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/helpers.sh
source "$SCRIPT_DIR/helpers.sh"

# Initialize test environment with required modules
# shellcheck disable=SC2119
init_test_env
# shellcheck source=lib/cli.sh
source "$ROOT_DIR/lib/cli.sh"

# =============================================================================
# Default value tests
# =============================================================================

test_parse_args_default_values() {
    parse_install_args

    assert "Default INSTALL_FORCE should be false" \
        test "$INSTALL_FORCE" == "false"
    assert "Default INSTALL_ADOPT should be false" \
        test "$INSTALL_ADOPT" == "false"
    assert "Default INSTALL_DEPS_ONLY should be false" \
        test "$INSTALL_DEPS_ONLY" == "false"
    assert "Default INSTALL_WITH_DEPS should be false" \
        test "$INSTALL_WITH_DEPS" == "false"
    assert "Default INSTALL_PACKAGES should be empty" \
        test "${#INSTALL_PACKAGES[@]}" -eq 0
}

# =============================================================================
# Flag parsing tests
# =============================================================================

test_parse_args_force_long_flag() {
    parse_install_args --force

    assert "INSTALL_FORCE should be true" \
        test "$INSTALL_FORCE" == "true"
}

test_parse_args_force_short_flag() {
    parse_install_args -f

    assert "INSTALL_FORCE should be true with -f" \
        test "$INSTALL_FORCE" == "true"
}

test_parse_args_adopt_long_flag() {
    parse_install_args --adopt

    assert "INSTALL_ADOPT should be true" \
        test "$INSTALL_ADOPT" == "true"
}

test_parse_args_adopt_short_flag() {
    parse_install_args -a

    assert "INSTALL_ADOPT should be true with -a" \
        test "$INSTALL_ADOPT" == "true"
}

test_parse_args_deps_only_flag() {
    parse_install_args --deps-only

    assert "INSTALL_DEPS_ONLY should be true" \
        test "$INSTALL_DEPS_ONLY" == "true"
}

test_parse_args_with_deps_flag() {
    parse_install_args --with-deps

    assert "INSTALL_WITH_DEPS should be true" \
        test "$INSTALL_WITH_DEPS" == "true"
}

# =============================================================================
# Multiple flags tests
# =============================================================================

test_parse_args_multiple_flags() {
    parse_install_args --force --adopt --with-deps

    assert "INSTALL_FORCE should be true" \
        test "$INSTALL_FORCE" == "true"
    assert "INSTALL_ADOPT should be true" \
        test "$INSTALL_ADOPT" == "true"
    assert "INSTALL_WITH_DEPS should be true" \
        test "$INSTALL_WITH_DEPS" == "true"
}

test_parse_args_short_flags_combined() {
    parse_install_args -f -a

    assert "INSTALL_FORCE should be true" \
        test "$INSTALL_FORCE" == "true"
    assert "INSTALL_ADOPT should be true" \
        test "$INSTALL_ADOPT" == "true"
}

# =============================================================================
# Package argument tests
# =============================================================================

test_parse_args_single_package() {
    parse_install_args nvim

    assert "Should have 1 package" \
        test "${#INSTALL_PACKAGES[@]}" -eq 1
    assert "Package should be nvim" \
        test "${INSTALL_PACKAGES[0]}" == "nvim"
}

test_parse_args_multiple_packages() {
    parse_install_args nvim git zsh

    assert "Should have 3 packages" \
        test "${#INSTALL_PACKAGES[@]}" -eq 3
    assert "First package should be nvim" \
        test "${INSTALL_PACKAGES[0]}" == "nvim"
    assert "Second package should be git" \
        test "${INSTALL_PACKAGES[1]}" == "git"
    assert "Third package should be zsh" \
        test "${INSTALL_PACKAGES[2]}" == "zsh"
}

# =============================================================================
# Mixed flags and packages tests
# =============================================================================

test_parse_args_flags_before_packages() {
    parse_install_args --force nvim git

    assert "INSTALL_FORCE should be true" \
        test "$INSTALL_FORCE" == "true"
    assert "Should have 2 packages" \
        test "${#INSTALL_PACKAGES[@]}" -eq 2
    assert "First package should be nvim" \
        test "${INSTALL_PACKAGES[0]}" == "nvim"
}

test_parse_args_flags_after_packages() {
    parse_install_args nvim --force git

    assert "INSTALL_FORCE should be true" \
        test "$INSTALL_FORCE" == "true"
    assert "Should have 2 packages" \
        test "${#INSTALL_PACKAGES[@]}" -eq 2
}

test_parse_args_flags_mixed_with_packages() {
    parse_install_args --force nvim --with-deps git --adopt

    assert "INSTALL_FORCE should be true" \
        test "$INSTALL_FORCE" == "true"
    assert "INSTALL_WITH_DEPS should be true" \
        test "$INSTALL_WITH_DEPS" == "true"
    assert "INSTALL_ADOPT should be true" \
        test "$INSTALL_ADOPT" == "true"
    assert "Should have 2 packages" \
        test "${#INSTALL_PACKAGES[@]}" -eq 2
}

# =============================================================================
# Reset behavior tests (important for multiple parses in tests)
# =============================================================================

test_parse_args_resets_on_reparse() {
    # First parse with flags
    parse_install_args --force nvim

    assert "First parse: INSTALL_FORCE should be true" \
        test "$INSTALL_FORCE" == "true"
    assert "First parse: Should have 1 package" \
        test "${#INSTALL_PACKAGES[@]}" -eq 1

    # Second parse without flags - should reset
    parse_install_args git

    assert "Second parse: INSTALL_FORCE should reset to false" \
        test "$INSTALL_FORCE" == "false"
    assert "Second parse: Should have 1 package (git)" \
        test "${#INSTALL_PACKAGES[@]}" -eq 1
    assert "Second parse: Package should be git" \
        test "${INSTALL_PACKAGES[0]}" == "git"
}

# =============================================================================
# resolve_packages tests
# =============================================================================

test_resolve_packages_returns_all_when_empty() {
    local result
    result=$(resolve_packages)

    # Should contain at least some known packages
    assert_contains "$result" "zsh"
    assert_contains "$result" "git"
    assert_contains "$result" "nvim"
}

test_resolve_packages_returns_valid_packages() {
    local result
    result=$(resolve_packages nvim git)

    assert_contains "$result" "nvim"
    assert_contains "$result" "git"
}

test_resolve_packages_filters_invalid_packages() {
    local result
    result=$(resolve_packages nvim invalid_package_xyz git 2>/dev/null)

    assert_contains "$result" "nvim"
    assert_contains "$result" "git"
    # Should not contain invalid package
    if echo "$result" | grep -q "invalid_package_xyz"; then
        echo "  Invalid package should be filtered out"
        return 1
    fi
    return 0
}

test_is_valid_package_true_for_known() {
    assert "nvim should be valid" is_valid_package "nvim"
    assert "git should be valid" is_valid_package "git"
    assert "zsh should be valid" is_valid_package "zsh"
}

test_is_valid_package_false_for_unknown() {
    assert_fails "nonexistent should be invalid" \
        is_valid_package "nonexistent_package_xyz"
}

# =============================================================================
# Run all tests
# =============================================================================
run_all_tests
