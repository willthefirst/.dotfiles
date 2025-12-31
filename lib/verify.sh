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
            if [[ "$target" == *"$DOTFILES_DIR"* ]] || [[ "$target" == *"$WORK_DOTFILES_DIR"* ]]; then
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
    echo ""
    log_info "Verifying installation..."

    local all_good=true

    # Check main symlinks
    for link in "${VERIFY_SYMLINKS[@]}"; do
        local stow_link
        if stow_link=$(is_stow_managed "$link"); then
            if [[ "$stow_link" == "$link" ]]; then
                echo -e "  ${GREEN}[ok]${NC} $link -> $(readlink "$link")"
            else
                echo -e "  ${GREEN}[ok]${NC} $link (via $stow_link)"
            fi
        elif [[ -e "$link" ]]; then
            echo -e "  ${YELLOW}[!]${NC} $link (exists but not managed by stow)"
            all_good=false
        else
            echo -e "  ${RED}[x]${NC} $link (not found)"
            all_good=false
        fi
    done

    # Check work overlay files
    echo ""
    log_info "Work overlay status:"
    for file in "${WORK_FILES[@]}"; do
        if [[ -e "$file" ]]; then
            echo -e "  ${GREEN}[ok]${NC} $file"
        else
            echo -e "  ${YELLOW}[o]${NC} $file (not installed)"
        fi
    done

    echo ""
    if $all_good && [[ "${INSTALL_WARNINGS:-false}" != "true" ]]; then
        log_info "Installation complete!"
    else
        log_warn "Installation complete with warnings. Check output above."
    fi
}
