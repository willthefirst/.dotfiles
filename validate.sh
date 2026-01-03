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
# shellcheck source=lib/validate.sh
source "$SCRIPT_DIR/lib/validate.sh"

errors=0

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

    # Run convention linting
    log_section "Running convention lints..."
    if ! "$SCRIPT_DIR/scripts/lint-conventions.sh"; then
        ((errors++)) || true
    fi

    echo ""
    if [[ $errors -eq 0 ]]; then
        log_ok "All validations passed!"
    else
        log_error "$errors validation(s) failed"
        exit 1
    fi
}

main
