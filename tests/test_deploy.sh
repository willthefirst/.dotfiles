#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Tests for deployment logic
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Source required modules
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/config.sh"
source "$ROOT_DIR/lib/conflicts.sh"
source "$ROOT_DIR/lib/backup.sh"
source "$ROOT_DIR/lib/deploy.sh"
source "$ROOT_DIR/lib/verify.sh"

# Test variables
TEST_HOME=""
TEST_DOTFILES=""
ORIGINAL_HOME=""
ORIGINAL_DOTFILES_DIR=""

setup() {
    TEST_HOME=$(mktemp -d)
    TEST_DOTFILES=$(mktemp -d)
    ORIGINAL_HOME="$HOME"
    ORIGINAL_DOTFILES_DIR="$DOTFILES_DIR"

    # Override for testing
    HOME="$TEST_HOME"
    DOTFILES_DIR="$TEST_DOTFILES"

    # Create required directories
    mkdir -p "$TEST_HOME/.config"
    mkdir -p "$TEST_HOME/.ssh"
}

teardown() {
    HOME="$ORIGINAL_HOME"
    DOTFILES_DIR="$ORIGINAL_DOTFILES_DIR"
    rm -rf "$TEST_HOME" "$TEST_DOTFILES"
}

test_create_directories_creates_config() {
    setup

    # Remove .config if it exists
    rm -rf "$TEST_HOME/.config"

    create_directories > /dev/null 2>&1

    if [[ -d "$TEST_HOME/.config" ]]; then
        echo "PASS: test_create_directories_creates_config"
    else
        echo "FAIL: test_create_directories_creates_config"
        echo "  Expected .config directory to be created"
    fi

    teardown
}

test_create_directories_creates_ssh_sockets() {
    setup

    create_directories > /dev/null 2>&1

    if [[ -d "$TEST_HOME/.ssh/sockets" ]]; then
        echo "PASS: test_create_directories_creates_ssh_sockets"
    else
        echo "FAIL: test_create_directories_creates_ssh_sockets"
        echo "  Expected .ssh/sockets directory to be created"
    fi

    teardown
}

test_create_directories_sets_ssh_permissions() {
    setup

    create_directories > /dev/null 2>&1

    local perms
    perms=$(stat -f "%Lp" "$TEST_HOME/.ssh" 2>/dev/null || stat -c "%a" "$TEST_HOME/.ssh" 2>/dev/null)

    if [[ "$perms" == "700" ]]; then
        echo "PASS: test_create_directories_sets_ssh_permissions"
    else
        echo "FAIL: test_create_directories_sets_ssh_permissions"
        echo "  Expected permissions 700, got: $perms"
    fi

    teardown
}

test_deploy_packages_creates_symlinks() {
    setup

    # Create a simple package
    mkdir -p "$TEST_DOTFILES/zsh"
    echo "# test zshrc" > "$TEST_DOTFILES/zsh/.zshrc"

    # Override PACKAGES for this test
    local PACKAGES=(zsh)

    # Deploy the package
    if deploy_packages "$TEST_DOTFILES" "zsh" > /dev/null 2>&1; then
        if [[ -L "$TEST_HOME/.zshrc" ]]; then
            echo "PASS: test_deploy_packages_creates_symlinks"
        else
            echo "FAIL: test_deploy_packages_creates_symlinks"
            echo "  Expected .zshrc symlink to be created"
        fi
    else
        echo "FAIL: test_deploy_packages_creates_symlinks"
        echo "  deploy_packages failed"
    fi

    teardown
}

test_is_stow_managed_detects_direct_symlink() {
    setup

    # Create a stow-managed symlink
    mkdir -p "$TEST_DOTFILES/zsh"
    touch "$TEST_DOTFILES/zsh/.zshrc"
    ln -s "$TEST_DOTFILES/zsh/.zshrc" "$TEST_HOME/.zshrc"

    if is_stow_managed "$TEST_HOME/.zshrc" > /dev/null; then
        echo "PASS: test_is_stow_managed_detects_direct_symlink"
    else
        echo "FAIL: test_is_stow_managed_detects_direct_symlink"
        echo "  Expected is_stow_managed to return true"
    fi

    teardown
}

test_is_stow_managed_detects_parent_symlink() {
    setup

    # Create a stow-managed directory symlink
    mkdir -p "$TEST_DOTFILES/nvim/.config/nvim"
    touch "$TEST_DOTFILES/nvim/.config/nvim/init.lua"
    mkdir -p "$TEST_HOME/.config"
    ln -s "$TEST_DOTFILES/nvim/.config/nvim" "$TEST_HOME/.config/nvim"

    if is_stow_managed "$TEST_HOME/.config/nvim/init.lua" > /dev/null; then
        echo "PASS: test_is_stow_managed_detects_parent_symlink"
    else
        echo "FAIL: test_is_stow_managed_detects_parent_symlink"
        echo "  Expected is_stow_managed to return true for file under symlinked dir"
    fi

    teardown
}

# Run all tests
test_create_directories_creates_config
test_create_directories_creates_ssh_sockets
test_create_directories_sets_ssh_permissions
test_deploy_packages_creates_symlinks
test_is_stow_managed_detects_direct_symlink
test_is_stow_managed_detects_parent_symlink
