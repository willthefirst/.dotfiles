#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Installation verification
# =============================================================================

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
            echo "      $issue"
        done
    fi
}
