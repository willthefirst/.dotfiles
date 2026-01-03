#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Test mocks - helpers for creating mock packages and test fixtures
# =============================================================================
# This module provides functions to create mock stow packages and test data.
# Requires TEST_DOTFILES to be set (by framework.sh setup_test_env).
# =============================================================================

# Create a mock stow package
# Usage: create_mock_package "package_name" "relative/path/to/file"
create_mock_package() {
    local pkg="$1"
    local file_path="$2"
    local pkg_dir="$TEST_DOTFILES/$pkg"
    local full_path="$pkg_dir/$file_path"

    mkdir -p "$(dirname "$full_path")"
    touch "$full_path"
}

# Create a mock stow package with content
# Usage: create_mock_package_with_content "package_name" "relative/path" "content"
create_mock_package_with_content() {
    local pkg="$1"
    local file_path="$2"
    local content="$3"
    local pkg_dir="$TEST_DOTFILES/$pkg"
    local full_path="$pkg_dir/$file_path"

    mkdir -p "$(dirname "$full_path")"
    echo "$content" > "$full_path"
}
