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

    echo ""
    if $all_good; then
        echo "✓ Installation verified ($count configs)"
    else
        echo -e "${YELLOW}⚠${NC} Installation complete with warnings:"
        for issue in "${issues[@]}"; do
            echo "  - $issue"
        done
    fi
}
