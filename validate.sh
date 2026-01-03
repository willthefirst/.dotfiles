#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Validate configuration files before deployment
# =============================================================================
# Validators are auto-discovered based on packages in PACKAGE_CONFIG.
# To add validation for a new package, define a validate_<pkg>() function.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"

errors=0

# =============================================================================
# Validation helpers - reduce repetition in validators
# =============================================================================

# Run a validation check and report result
# Usage: check "description" command [args...]
# Returns: 0 on success, 1 on failure (also increments errors)
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

# =============================================================================
# Package validators
# =============================================================================

validate_zsh() {
    log_step "Validating zsh config..."
    local zsh_output
    if zsh_output=$(zsh -n "$SCRIPT_DIR/zsh/.zshrc" 2>&1); then
        log_ok "zsh/.zshrc syntax valid"
    else
        log_error "zsh/.zshrc has syntax errors"
        log_info "$zsh_output"
        ((errors++)) || true
    fi
}

validate_git() {
    log_step "Validating git config..."
    check "git/.gitconfig valid" \
        git config --file "$SCRIPT_DIR/git/.gitconfig" --list

    local personal="$SCRIPT_DIR/git/.gitconfig.personal"
    if [[ -f "$personal" ]]; then
        check "git/.gitconfig.personal valid" \
            git config --file "$personal" --list
    else
        log_warn "git/.gitconfig.personal not found"
    fi
}

validate_ssh() {
    log_step "Validating ssh config..."
    local ssh_config="$SCRIPT_DIR/ssh/.ssh/config"
    if check_file "$ssh_config" "ssh/.ssh/config exists"; then
        if grep -q "^Host " "$ssh_config"; then
            log_ok "ssh/.ssh/config has Host entries"
        else
            log_warn "ssh/.ssh/config has no Host entries"
        fi
    fi
}

validate_nvim() {
    log_step "Validating nvim config..."
    require_cmd nvim "nvim not installed, skipping" || return 0
    check_warn "nvim config loads" \
        nvim --headless -c "lua print('ok')" -c "qa"
}

validate_ghostty() {
    log_step "Validating ghostty config..."
    check_file "$SCRIPT_DIR/ghostty/.config/ghostty/config" \
        "ghostty config exists" \
        "ghostty config not found (may be empty)"
}

# =============================================================================
# Main
# =============================================================================

main() {
    log_section "Validating configuration files..."

    for pkg in "${PACKAGES[@]}"; do
        local validator="validate_${pkg}"
        if declare -f "$validator" >/dev/null; then
            "$validator"
        fi
    done

    echo ""
    if [[ $errors -eq 0 ]]; then
        log_ok "All validations passed!"
    else
        log_error "$errors validation(s) failed"
        exit 1
    fi
}

main
