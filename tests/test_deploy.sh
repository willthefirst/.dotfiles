#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Tests for deployment logic
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/helpers.sh
source "$SCRIPT_DIR/helpers.sh"
init_test_env conflicts backup deploy verify

# =============================================================================
# Test functions - each returns 0 for pass, non-zero for fail
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

test_deploy_packages_creates_symlinks() {
    mkdir -p "$TEST_DOTFILES/zsh"
    echo "# test zshrc" > "$TEST_DOTFILES/zsh/.zshrc"

    deploy_packages "$TEST_DOTFILES" "false" "zsh" > /dev/null 2>&1 || return 1
    assert "Expected .zshrc symlink" test -L "$TEST_HOME/.zshrc"
}

test_is_dotfiles_managed_detects_direct_symlink() {
    mkdir -p "$TEST_DOTFILES/zsh"
    touch "$TEST_DOTFILES/zsh/.zshrc"
    ln -s "$TEST_DOTFILES/zsh/.zshrc" "$TEST_HOME/.zshrc"

    assert "Expected is_dotfiles_managed to return true" is_dotfiles_managed "$TEST_HOME/.zshrc"
}

test_is_dotfiles_managed_detects_parent_symlink() {
    mkdir -p "$TEST_DOTFILES/nvim/.config/nvim"
    touch "$TEST_DOTFILES/nvim/.config/nvim/init.lua"
    mkdir -p "$TEST_HOME/.config"
    ln -s "$TEST_DOTFILES/nvim/.config/nvim" "$TEST_HOME/.config/nvim"

    assert "Expected is_dotfiles_managed to return true for file under symlinked dir" \
        is_dotfiles_managed "$TEST_HOME/.config/nvim/init.lua"
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

test_config_has_content() {
    mkdir -p "$TEST_DOTFILES/ghostty/.config/ghostty"
    cat > "$TEST_DOTFILES/ghostty/.config/ghostty/config" <<'EOF'
# This is the configuration file for Ghostty.
#
# This template file has been automatically created
# All options are commented out
EOF

    deploy_packages "$TEST_DOTFILES" "false" "ghostty" > /dev/null 2>&1

    local content_lines
    content_lines=$(grep -v '^#' "$TEST_HOME/.config/ghostty/config" | grep -cv '^[[:space:]]*$')

    assert "Expected 0 content lines in template config, got: $content_lines" \
        test "$content_lines" -eq 0
}

test_no_broken_symlinks_in_app_support() {
    local app_support="$TEST_HOME/Library/Application Support/com.test.app"
    mkdir -p "$app_support"
    ln -s "$TEST_HOME/.dotfiles/nonexistent-config" "$app_support/config"

    local broken_links
    broken_links=$(find "$TEST_HOME/Library/Application Support" -type l ! -exec test -e {} \; -print 2>/dev/null | wc -l)

    assert "Expected to detect broken symlinks" test "$broken_links" -gt 0
}

test_verify_installation_reports_all_good() {
    # Create a managed symlink
    mkdir -p "$TEST_DOTFILES/zsh"
    touch "$TEST_DOTFILES/zsh/.zshrc"
    ln -s "$TEST_DOTFILES/zsh/.zshrc" "$TEST_HOME/.zshrc"

    # Override VERIFY_SYMLINKS for this test
    VERIFY_SYMLINKS=("$TEST_HOME/.zshrc")

    local output
    output=$(verify_installation 2>&1)
    assert_contains "$output" "Verified (1 configs)"
}

test_verify_installation_warns_on_unmanaged_file() {
    # Create a regular file (not managed by stow)
    echo "not managed" > "$TEST_HOME/.zshrc"

    # Override VERIFY_SYMLINKS for this test
    VERIFY_SYMLINKS=("$TEST_HOME/.zshrc")

    local output
    output=$(verify_installation 2>&1)
    assert_contains "$output" "exists but not managed by stow"
}

test_verify_installation_warns_on_missing_file() {
    # Don't create the file - it should be missing
    VERIFY_SYMLINKS=("$TEST_HOME/.nonexistent")

    local output
    output=$(verify_installation 2>&1)
    assert_contains "$output" "not found"
}

test_verify_installation_counts_multiple_configs() {
    # Create multiple managed symlinks
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

test_deploy_packages_returns_failure_on_conflict() {
    # Create package directory
    mkdir -p "$TEST_DOTFILES/zsh"
    echo "# from dotfiles" > "$TEST_DOTFILES/zsh/.zshrc"

    # Create conflicting file at target location
    echo "# existing file" > "$TEST_HOME/.zshrc"

    # deploy_packages should fail because of the conflict
    local result=0
    deploy_packages "$TEST_DOTFILES" "false" "zsh" > /dev/null 2>&1 || result=$?

    assert "Expected deploy_packages to fail with conflict" test "$result" -ne 0
}

test_deploy_packages_outputs_error_on_failure() {
    # Create package directory
    mkdir -p "$TEST_DOTFILES/zsh"
    echo "# from dotfiles" > "$TEST_DOTFILES/zsh/.zshrc"

    # Create conflicting file at target location
    echo "# existing file" > "$TEST_HOME/.zshrc"

    # Should show error output
    local output
    output=$(deploy_packages "$TEST_DOTFILES" "false" "zsh" 2>&1)

    assert_contains "$output" "zsh"
}

test_deploy_packages_handles_empty_package_list() {
    # Empty package list should succeed (nothing to deploy)
    local result=0
    deploy_packages "$TEST_DOTFILES" "false" > /dev/null 2>&1 || result=$?
    assert "Expected deploy_packages to succeed with empty package list" test "$result" -eq 0
}

# =============================================================================
# Run all tests
# =============================================================================
run_all_tests
