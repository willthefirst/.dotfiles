#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Tests for verify_installation (lib/verify.sh)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/helpers.sh
source "$SCRIPT_DIR/helpers.sh"
init_test_env verify

# =============================================================================
# verify_installation tests
# =============================================================================

test_verify_installation_reports_all_good() {
    mkdir -p "$TEST_DOTFILES/zsh"
    touch "$TEST_DOTFILES/zsh/.zshrc"
    ln -s "$TEST_DOTFILES/zsh/.zshrc" "$TEST_HOME/.zshrc"

    VERIFY_SYMLINKS=("$TEST_HOME/.zshrc")

    local output
    output=$(verify_installation 2>&1)
    assert_contains "$output" "Verified (1 configs)"
}

test_verify_installation_warns_on_unmanaged_file() {
    echo "not managed" > "$TEST_HOME/.zshrc"

    VERIFY_SYMLINKS=("$TEST_HOME/.zshrc")

    local output
    output=$(verify_installation 2>&1)
    assert_contains "$output" "exists but not managed by stow"
}

test_verify_installation_warns_on_missing_file() {
    VERIFY_SYMLINKS=("$TEST_HOME/.nonexistent")

    local output
    output=$(verify_installation 2>&1)
    assert_contains "$output" "not found"
}

test_verify_installation_counts_multiple_configs() {
    mkdir -p "$TEST_DOTFILES/zsh"
    mkdir -p "$TEST_DOTFILES/git"
    touch "$TEST_DOTFILES/zsh/.zshrc"
    touch "$TEST_DOTFILES/git/.gitconfig"
    ln -s "$TEST_DOTFILES/zsh/.zshrc" "$TEST_HOME/.zshrc"
    ln -s "$TEST_DOTFILES/git/.gitconfig" "$TEST_HOME/.gitconfig"

    VERIFY_SYMLINKS=("$TEST_HOME/.zshrc" "$TEST_HOME/.gitconfig")

    local output
    output=$(verify_installation 2>&1)
    assert_contains "$output" "Verified (2 configs)"
}

test_verify_installation_handles_empty_list() {
    # shellcheck disable=SC2034  # VERIFY_SYMLINKS is used by verify_installation
    VERIFY_SYMLINKS=()

    local output
    output=$(verify_installation 2>&1)
    assert_contains "$output" "Verified (0 configs)"
}

# =============================================================================
# Run all tests
# =============================================================================
run_all_tests
