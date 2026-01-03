#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# lib/verify.sh - Installation verification
# =============================================================================
# Dependencies: log.sh, fs.sh, config.sh
# Provides: verify_installation
# =============================================================================

# Source guard - prevent multiple loading
[[ -n "${_DOTFILES_VERIFY_LOADED:-}" ]] && return 0
_DOTFILES_VERIFY_LOADED=1

# Source dependencies
# shellcheck source=lib/log.sh
source "${BASH_SOURCE%/*}/log.sh"
# shellcheck source=lib/fs.sh
source "${BASH_SOURCE%/*}/fs.sh"
# shellcheck source=lib/config.sh
source "${BASH_SOURCE%/*}/config.sh"

# Verify all symlinks are properly installed
verify_installation() {
    local all_good=true
    local count=0
    local issues=()

    # Check main symlinks
    for link in "${VERIFY_SYMLINKS[@]}"; do
        if is_dotfiles_managed "$link"; then
            count=$((count + 1))
        elif [[ -e "$link" ]]; then
            issues+=("$link exists but not managed by stow")
            all_good=false
        else
            issues+=("$link not found")
            all_good=false
        fi
    done

    if $all_good; then
        log_ok "Verified ($count configs)"
    else
        log_warn "Complete with warnings:"
        for issue in "${issues[@]}"; do
            log_info "    $issue"
        done
    fi
}
