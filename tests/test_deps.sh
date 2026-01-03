#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Tests for dependency installation module (lib/deps.sh)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/helpers.sh
source "$SCRIPT_DIR/helpers.sh"
init_test_env deps

# Custom setup/teardown for dry run mode
setup() {
    setup_test_env true
    deps_dry_run_enable
}

teardown() {
    deps_dry_run_disable
    teardown_test_env
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
    printf '\tpackage1\t\n' > "$TEST_DOTFILES/deps"
    printf 'package2\t# comment\n' >> "$TEST_DOTFILES/deps"
    local output
    output=$(read_deps_file "$TEST_DOTFILES/deps")
    assert_contains "$output" "package1"
    assert_contains "$output" "package2"
    if echo "$output" | grep -q $'\t'; then
        echo "  Tabs were not trimmed from output"
        return 1
    fi
    return 0
}

test_read_deps_file_handles_crlf_line_endings() {
    printf 'package1\r\npackage2\r\n' > "$TEST_DOTFILES/deps"
    local output
    output=$(read_deps_file "$TEST_DOTFILES/deps")
    local line_count
    line_count=$(echo "$output" | grep -c .)
    assert "Expected 2 packages with CRLF input, got $line_count" test "$line_count" -eq 2
    if echo "$output" | grep -q $'\r'; then
        echo "  Carriage returns were not stripped"
        return 1
    fi
    return 0
}

test_read_deps_file_handles_mixed_whitespace() {
    printf '  \t  package1  \t  \n' > "$TEST_DOTFILES/deps"
    printf '\t\tpackage2   # comment with trailing spaces   \n' >> "$TEST_DOTFILES/deps"
    local output
    output=$(read_deps_file "$TEST_DOTFILES/deps")
    local first_line
    first_line=$(echo "$output" | head -1)
    assert "Expected 'package1', got: '$first_line'" test "$first_line" == "package1"
}

# =============================================================================
# Package installation tests
# =============================================================================

test_install_package_deps_skips_missing_package() {
    local output
    output=$(install_package_deps "nonexistent" 2>&1)
    assert_contains "$output" "not found"
}

test_install_package_deps_skips_package_without_deps() {
    mkdir -p "$TEST_DOTFILES/empty_pkg/.config/test"
    touch "$TEST_DOTFILES/empty_pkg/.config/test/config"

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
    ensure_dir "$TEST_HOME/existingdir"
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
run_all_tests
