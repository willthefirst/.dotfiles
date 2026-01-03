#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Tests for dependency installation module
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Source required modules
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/config.sh"
source "$ROOT_DIR/lib/deps.sh"
# shellcheck source=tests/helpers.sh
source "$SCRIPT_DIR/helpers.sh"

setup() {
    setup_test_env true
    deps_dry_run_enable  # Don't actually install packages in tests
}

teardown() {
    deps_dry_run_disable
    teardown_test_env
}

# =============================================================================
# Platform detection tests
# =============================================================================

test_is_darwin_or_is_linux() {
    # At least one should be true
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

# =============================================================================
# Deps file parsing tests
# =============================================================================

test_read_deps_file_handles_missing_file() {
    local output
    output=$(read_deps_file "$TEST_DOTFILES/nonexistent")
    assert "Expected empty output for missing file" test -z "$output"
}

test_read_deps_file_reads_packages() {
    echo -e "package1\npackage2" > "$TEST_DOTFILES/deps"
    local output
    output=$(read_deps_file "$TEST_DOTFILES/deps")
    assert_contains "$output" "package1"
    assert_contains "$output" "package2"
}

test_read_deps_file_skips_comments() {
    cat > "$TEST_DOTFILES/deps" <<EOF
package1
# this is a comment
package2
EOF
    local output
    output=$(read_deps_file "$TEST_DOTFILES/deps")
    assert_contains "$output" "package1"
    assert_contains "$output" "package2"
    if echo "$output" | grep -q "comment"; then
        echo "  Comment was not filtered out"
        return 1
    fi
    return 0
}

test_read_deps_file_skips_empty_lines() {
    cat > "$TEST_DOTFILES/deps" <<EOF
package1

package2
EOF
    local output
    output=$(read_deps_file "$TEST_DOTFILES/deps")
    local line_count
    line_count=$(echo "$output" | grep -c .)
    assert "Expected 2 packages, got $line_count" test "$line_count" -eq 2
}

test_read_deps_file_handles_inline_comments() {
    echo "package1 # inline comment" > "$TEST_DOTFILES/deps"
    local output
    output=$(read_deps_file "$TEST_DOTFILES/deps")
    assert "Expected 'package1', got: $output" test "$output" == "package1"
}

test_read_deps_file_handles_tabs() {
    # Use printf to ensure tabs are preserved
    printf '\tpackage1\t\n' > "$TEST_DOTFILES/deps"
    printf 'package2\t# comment\n' >> "$TEST_DOTFILES/deps"
    local output
    output=$(read_deps_file "$TEST_DOTFILES/deps")
    assert_contains "$output" "package1"
    assert_contains "$output" "package2"
    # Verify no tabs remain in output
    if echo "$output" | grep -q $'\t'; then
        echo "  Tabs were not trimmed from output"
        return 1
    fi
    return 0
}

test_read_deps_file_handles_crlf_line_endings() {
    # Create file with Windows-style CRLF line endings
    printf 'package1\r\npackage2\r\n' > "$TEST_DOTFILES/deps"
    local output
    output=$(read_deps_file "$TEST_DOTFILES/deps")
    # Should have 2 packages without carriage returns
    local line_count
    line_count=$(echo "$output" | grep -c .)
    assert "Expected 2 packages with CRLF input, got $line_count" test "$line_count" -eq 2
    # Verify no carriage returns remain
    if echo "$output" | grep -q $'\r'; then
        echo "  Carriage returns were not stripped"
        return 1
    fi
    return 0
}

test_read_deps_file_handles_mixed_whitespace() {
    # Mix of tabs, spaces, and content
    printf '  \t  package1  \t  \n' > "$TEST_DOTFILES/deps"
    printf '\t\tpackage2   # comment with trailing spaces   \n' >> "$TEST_DOTFILES/deps"
    local output
    output=$(read_deps_file "$TEST_DOTFILES/deps")
    # First line should be exactly "package1"
    local first_line
    first_line=$(echo "$output" | head -1)
    assert "Expected 'package1', got: '$first_line'" test "$first_line" == "package1"
}

# =============================================================================
# Install order tests
# =============================================================================

test_install_package_deps_skips_missing_package() {
    local output
    output=$(install_package_deps "nonexistent" 2>&1)
    # Should not error, just warn
    assert_contains "$output" "not found"
}

test_install_package_deps_skips_package_without_deps() {
    mkdir -p "$TEST_DOTFILES/empty_pkg/.config/test"
    touch "$TEST_DOTFILES/empty_pkg/.config/test/config"

    # Should succeed silently with no deps files
    install_package_deps "empty_pkg"
}

test_install_package_deps_reads_common_deps() {
    mkdir -p "$TEST_DOTFILES/testpkg"
    echo "testdep" > "$TEST_DOTFILES/testpkg/deps"

    local output
    output=$(install_package_deps "testpkg" 2>&1)
    assert_contains "$output" "testdep"
}

test_install_package_deps_reads_platform_deps() {
    mkdir -p "$TEST_DOTFILES/testpkg"
    local platform
    platform=$(get_platform_suffix)
    echo "platform-dep" > "$TEST_DOTFILES/testpkg/deps.$platform"

    local output
    output=$(install_package_deps "testpkg" 2>&1)
    assert_contains "$output" "platform-dep"
}

test_install_package_deps_runs_install_function() {
    mkdir -p "$TEST_DOTFILES/testpkg"
    cat > "$TEST_DOTFILES/testpkg/install.sh" <<'EOF'
install_testpkg() {
    echo "CUSTOM_INSTALL_RAN"
}
EOF

    local output
    output=$(install_package_deps "testpkg" 2>&1)
    assert_contains "$output" "testpkg"
    assert_contains "$output" "custom"
}

test_install_order_runs_install_sh_before_deps() {
    mkdir -p "$TEST_DOTFILES/orderpkg"
    echo "dep1" > "$TEST_DOTFILES/orderpkg/deps"
    cat > "$TEST_DOTFILES/orderpkg/install.sh" <<'EOF'
install_orderpkg() {
    echo "INSTALL_FIRST"
}
EOF

    local output
    output=$(install_package_deps "orderpkg" 2>&1)

    # Get line numbers for each (custom install vs dep)
    local install_line dep_line
    install_line=$(echo "$output" | grep -n "custom" | head -1 | cut -d: -f1)
    dep_line=$(echo "$output" | grep -n "dep1" | head -1 | cut -d: -f1)

    if [[ -n "$install_line" && -n "$dep_line" ]]; then
        assert "Custom install should run before deps" test "$install_line" -lt "$dep_line"
    else
        echo "  Could not find both custom install and dep in output"
        return 1
    fi
}

# =============================================================================
# Utility function tests
# =============================================================================

test_has_command_finds_existing() {
    assert "Expected has_command to find 'bash'" has_command bash
}

test_has_command_fails_for_missing() {
    assert_fails "Expected has_command to fail for nonexistent command" \
        has_command nonexistent_command_12345
}

test_ensure_dir_creates_directory() {
    local test_dir="$TEST_HOME/newdir/nested"
    ensure_dir "$test_dir"
    assert_dir_exists "$test_dir"
}

test_ensure_dir_handles_existing() {
    mkdir -p "$TEST_HOME/existingdir"
    ensure_dir "$TEST_HOME/existingdir"  # Should not error
    assert_dir_exists "$TEST_HOME/existingdir"
}

# =============================================================================
# Dry run tests
# =============================================================================

test_dry_run_mode_prevents_install() {
    mkdir -p "$TEST_DOTFILES/drypkg"
    echo "somepackage" > "$TEST_DOTFILES/drypkg/deps"

    deps_dry_run_enable
    local output
    output=$(install_package_deps "drypkg" 2>&1)
    assert_contains "$output" "dry-run"
}

# =============================================================================
# Run all tests
# =============================================================================
run_test test_is_darwin_or_is_linux
run_test test_get_platform_suffix_returns_valid
run_test test_read_deps_file_handles_missing_file
run_test test_read_deps_file_reads_packages
run_test test_read_deps_file_skips_comments
run_test test_read_deps_file_skips_empty_lines
run_test test_read_deps_file_handles_inline_comments
run_test test_read_deps_file_handles_tabs
run_test test_read_deps_file_handles_crlf_line_endings
run_test test_read_deps_file_handles_mixed_whitespace
run_test test_install_package_deps_skips_missing_package
run_test test_install_package_deps_skips_package_without_deps
run_test test_install_package_deps_reads_common_deps
run_test test_install_package_deps_reads_platform_deps
run_test test_install_package_deps_runs_install_function
run_test test_install_order_runs_install_sh_before_deps
run_test test_has_command_finds_existing
run_test test_has_command_fails_for_missing
run_test test_ensure_dir_creates_directory
run_test test_ensure_dir_handles_existing
run_test test_dry_run_mode_prevents_install
