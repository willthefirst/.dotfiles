#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Installation verification
# =============================================================================

# Check if a path is managed by stow
# Returns the symlink path if managed, empty string if not
is_stow_managed() {
    local path="$1"
    local check_path="$path"

    # Check if the path itself or any parent is a symlink into dotfiles
    while [[ "$check_path" != "$HOME" && "$check_path" != "/" ]]; do
        if [[ -L "$check_path" ]]; then
            local target
            target=$(readlink -f "$check_path" 2>/dev/null || echo "")
            if [[ "$target" == *"$DOTFILES_DIR"* ]]; then
                echo "$check_path"
                return 0
            fi
        fi
        check_path=$(dirname "$check_path")
    done
    return 1
}

# Verify all symlinks are properly installed
verify_installation() {
    local all_good=true
    local count=0
    local issues=()

    # Check main symlinks
    for link in "${VERIFY_SYMLINKS[@]}"; do
        if is_stow_managed "$link" > /dev/null; then
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
