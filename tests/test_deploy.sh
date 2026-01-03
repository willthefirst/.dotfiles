#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Tests for deployment logic (lib/deploy.sh)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/helpers.sh
source "$SCRIPT_DIR/helpers.sh"
init_test_env conflicts backup deploy

# =============================================================================
# create_directories tests
# =============================================================================

test_create_directories_creates_config() {
    rm -rf "$TEST_HOME/.config"
    create_directories > /dev/null 2>&1
    assert_dir_exists "$TEST_HOME/.config"
}

test_create_directories_creates_ssh_sockets() {
    create_directories > /dev/null 2>&1
    assert_dir_exists "$TEST_HOME/.ssh/sockets"
}

test_create_directories_sets_ssh_permissions() {
    create_directories > /dev/null 2>&1
    assert_permissions "$TEST_HOME/.ssh" "700"
}

# =============================================================================
# deploy_packages tests
# =============================================================================

test_deploy_packages_creates_symlinks() {
    mkdir -p "$TEST_DOTFILES/zsh"
    echo "# test zshrc" > "$TEST_DOTFILES/zsh/.zshrc"

    deploy_packages "$TEST_DOTFILES" "false" "zsh" > /dev/null 2>&1 || return 1
    assert "Expected .zshrc symlink" test -L "$TEST_HOME/.zshrc"
}

test_deploy_packages_handles_nested_config() {
    mkdir -p "$TEST_DOTFILES/ghostty/.config/ghostty"
    echo "# test ghostty config" > "$TEST_DOTFILES/ghostty/.config/ghostty/config"

    deploy_packages "$TEST_DOTFILES" "false" "ghostty" > /dev/null 2>&1 || return 1
    assert "Expected .config/ghostty/config symlink" test -L "$TEST_HOME/.config/ghostty/config"
}

test_deploy_packages_warns_on_missing_package() {
    local output
    output=$(deploy_packages "$TEST_DOTFILES" "false" "nonexistent" 2>&1)
    assert_contains "$output" "Package not found"
}

test_deploy_packages_detects_file_instead_of_directory() {
    echo "# misconfigured" > "$TEST_DOTFILES/ghostty-config"

    local output
    output=$(deploy_packages "$TEST_DOTFILES" "false" "ghostty-config" 2>&1)
    assert_contains "$output" "Package not found"
}

test_deploy_packages_returns_failure_on_conflict() {
    mkdir -p "$TEST_DOTFILES/zsh"
    echo "# from dotfiles" > "$TEST_DOTFILES/zsh/.zshrc"
    echo "# existing file" > "$TEST_HOME/.zshrc"

    local result=0
    deploy_packages "$TEST_DOTFILES" "false" "zsh" > /dev/null 2>&1 || result=$?

    assert "Expected deploy_packages to fail with conflict" test "$result" -ne 0
}

test_deploy_packages_outputs_error_on_failure() {
    mkdir -p "$TEST_DOTFILES/zsh"
    echo "# from dotfiles" > "$TEST_DOTFILES/zsh/.zshrc"
    echo "# existing file" > "$TEST_HOME/.zshrc"

    local output
    output=$(deploy_packages "$TEST_DOTFILES" "false" "zsh" 2>&1)

    assert_contains "$output" "zsh"
}

test_deploy_packages_handles_empty_package_list() {
    local result=0
    deploy_packages "$TEST_DOTFILES" "false" > /dev/null 2>&1 || result=$?
    assert "Expected deploy_packages to succeed with empty package list" test "$result" -eq 0
}

# =============================================================================
# Run all tests
# =============================================================================
run_all_tests
