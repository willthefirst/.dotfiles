#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Test helpers - unified entry point for test framework
# =============================================================================
# Usage in test files:
#   source "$SCRIPT_DIR/helpers.sh"
#   init_test_env [modules...]   # Sources lib modules, e.g., "backup" "deploy"
#   # Define test_* functions
#   run_all_tests                # Auto-discovers and runs test_* functions
# =============================================================================
# This file sources the modular test framework components:
#   - framework.sh  - Test runner, setup/teardown, initialization
#   - assertions.sh - Assertion functions (assert_*, get_file_permissions)
#   - mocks.sh      - Mock package helpers (create_mock_package*)
# =============================================================================

HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$HELPERS_DIR")"

# Source modular components
# shellcheck source=tests/framework.sh
source "$HELPERS_DIR/framework.sh"
# shellcheck source=tests/assertions.sh
source "$HELPERS_DIR/assertions.sh"
# shellcheck source=tests/mocks.sh
source "$HELPERS_DIR/mocks.sh"
