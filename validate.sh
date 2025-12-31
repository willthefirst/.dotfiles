#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Validate configuration files before deployment
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

errors=0

validate_zsh() {
    log_info "Validating zsh config..."
    if zsh -n "$SCRIPT_DIR/zsh/.zshrc" 2>/dev/null; then
        log_info "  [ok] zsh/.zshrc syntax valid"
    else
        log_error "  [x] zsh/.zshrc has syntax errors"
        ((errors++)) || true
    fi
}

validate_git() {
    log_info "Validating git config..."
    if git config --file "$SCRIPT_DIR/git/.gitconfig" --list > /dev/null 2>&1; then
        log_info "  [ok] git/.gitconfig valid"
    else
        log_error "  [x] git/.gitconfig is invalid"
        ((errors++)) || true
    fi

    # Validate personal git config (1Password signing)
    if [[ -f "$SCRIPT_DIR/git/.gitconfig.personal" ]]; then
        if git config --file "$SCRIPT_DIR/git/.gitconfig.personal" --list > /dev/null 2>&1; then
            log_info "  [ok] git/.gitconfig.personal valid"
        else
            log_error "  [x] git/.gitconfig.personal is invalid"
            ((errors++)) || true
        fi
    else
        log_warn "  [!] git/.gitconfig.personal not found"
    fi
}

validate_ssh() {
    log_info "Validating ssh config..."
    local ssh_config="$SCRIPT_DIR/ssh/.ssh/config"
    if [[ -f "$ssh_config" ]]; then
        if grep -q "^Host " "$ssh_config"; then
            log_info "  [ok] ssh/.ssh/config has Host entries"
        else
            log_warn "  [!] ssh/.ssh/config has no Host entries"
        fi
    else
        log_warn "  [!] ssh/.ssh/config not found"
    fi
}

validate_nvim() {
    log_info "Validating nvim config..."
    if command -v nvim &> /dev/null; then
        if nvim --headless -c "lua print('ok')" -c "qa" 2>/dev/null; then
            log_info "  [ok] nvim config loads"
        else
            log_warn "  [!] nvim config has issues (non-fatal)"
        fi
    else
        log_info "  [-] nvim not installed, skipping"
    fi
}

validate_ghostty() {
    log_info "Validating ghostty config..."
    local ghostty_config="$SCRIPT_DIR/ghostty/.config/ghostty/config"
    if [[ -f "$ghostty_config" ]]; then
        log_info "  [ok] ghostty config exists"
    else
        log_info "  [-] ghostty config not found (may be empty)"
    fi
}

main() {
    echo "Validating configuration files..."
    echo ""

    validate_zsh
    validate_git
    validate_ssh
    validate_nvim
    validate_ghostty

    echo ""
    if [[ $errors -eq 0 ]]; then
        log_info "All validations passed!"
    else
        log_error "$errors validation(s) failed"
        exit 1
    fi
}

main
