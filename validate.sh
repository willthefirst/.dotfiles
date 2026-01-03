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
    if git config --file "$SCRIPT_DIR/git/.gitconfig" --list > /dev/null 2>&1; then
        log_ok "git/.gitconfig valid"
    else
        log_error "git/.gitconfig is invalid"
        ((errors++)) || true
    fi

    # Validate personal git config (1Password signing)
    if [[ -f "$SCRIPT_DIR/git/.gitconfig.personal" ]]; then
        if git config --file "$SCRIPT_DIR/git/.gitconfig.personal" --list > /dev/null 2>&1; then
            log_ok "git/.gitconfig.personal valid"
        else
            log_error "git/.gitconfig.personal is invalid"
            ((errors++)) || true
        fi
    else
        log_warn "git/.gitconfig.personal not found"
    fi
}

validate_ssh() {
    log_step "Validating ssh config..."
    local ssh_config="$SCRIPT_DIR/ssh/.ssh/config"
    if [[ -f "$ssh_config" ]]; then
        if grep -q "^Host " "$ssh_config"; then
            log_ok "ssh/.ssh/config has Host entries"
        else
            log_warn "ssh/.ssh/config has no Host entries"
        fi
    else
        log_warn "ssh/.ssh/config not found"
    fi
}

validate_nvim() {
    log_step "Validating nvim config..."
    if command -v nvim &> /dev/null; then
        if nvim --headless -c "lua print('ok')" -c "qa" 2>/dev/null; then
            log_ok "nvim config loads"
        else
            log_warn "nvim config has issues (non-fatal)"
        fi
    else
        log_info "nvim not installed, skipping"
    fi
}

validate_ghostty() {
    log_step "Validating ghostty config..."
    local ghostty_config="$SCRIPT_DIR/ghostty/.config/ghostty/config"
    if [[ -f "$ghostty_config" ]]; then
        log_ok "ghostty config exists"
    else
        log_info "ghostty config not found (may be empty)"
    fi
}

main() {
    log_section "Validating configuration files..."

    # Auto-discover and run validators for packages in PACKAGE_CONFIG
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
