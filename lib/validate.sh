#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Validation helpers for dotfiles scripts
# =============================================================================
# Provides reusable validation functions for checking commands, files, and
# running validation checks with consistent logging.
#
# Dependencies: lib/log.sh (for log_ok, log_error, log_warn, log_info)
#
# Usage: source this file after sourcing lib/log.sh
# =============================================================================

# Check if a command exists in PATH
# Usage: has_command <cmd>
# Returns 0 if exists, 1 if not
has_command() {
    command -v "$1" &>/dev/null
}

# Run a validation check and report result
# Usage: check "description" command [args...]
# Returns: 0 on success, 1 on failure (also increments errors global)
check() {
    local desc="$1"
    shift
    if "$@" > /dev/null 2>&1; then
        log_ok "$desc"
        return 0
    else
        log_error "$desc"
        ((errors++)) || true
        return 1
    fi
}

# Run a validation check, treating failure as warning (non-fatal)
# Usage: check_warn "description" command [args...]
check_warn() {
    local desc="$1"
    shift
    if "$@" > /dev/null 2>&1; then
        log_ok "$desc"
    else
        log_warn "$desc (non-fatal)"
    fi
}

# Check if a file exists
# Usage: check_file "path" "success_msg" ["missing_msg"]
check_file() {
    local path="$1"
    local success_msg="$2"
    local missing_msg="${3:-$path not found}"
    if [[ -f "$path" ]]; then
        log_ok "$success_msg"
        return 0
    else
        log_warn "$missing_msg"
        return 1
    fi
}

# Skip validation if command not available
# Usage: require_cmd "command" "skip message" || return
require_cmd() {
    local cmd="$1"
    local skip_msg="$2"
    if ! command -v "$cmd" &> /dev/null; then
        log_info "$skip_msg"
        return 1
    fi
    return 0
}
