#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Stow deployment logic
# =============================================================================

# Create required directories with proper permissions
create_directories() {
    log_info "Creating required directories..."
    mkdir -p "$HOME/.config"
    mkdir -p "$HOME/.ssh/sockets"
    chmod 700 "$HOME/.ssh"
    chmod 700 "$HOME/.ssh/sockets"
}

# Check prerequisites (GNU Stow)
check_prerequisites() {
    local install_hint=""
    install_hint+="Install it with:"$'\n'
    install_hint+="  macOS:  brew install stow"$'\n'
    install_hint+="  Ubuntu: sudo apt install stow"$'\n'
    install_hint+="  Arch:   sudo pacman -S stow"

    if ! require_command "stow" "$install_hint"; then
        exit 1
    fi
    log_info "GNU Stow found: $(command -v stow)"
}

# Deploy packages using stow
# Usage: deploy_packages base_dir package1 package2 ...
deploy_packages() {
    local base_dir="$1"
    shift
    local packages=("$@")
    local stow_opts=(-v -t "$HOME")

    if [[ "${ADOPT_MODE:-false}" == "true" ]]; then
        stow_opts+=(--adopt)
        log_info "Adopt mode: existing files will be adopted into stow packages"
    fi

    for pkg in "${packages[@]}"; do
        if [[ -d "$base_dir/$pkg" ]]; then
            log_info "  Stowing: $pkg"
            local stow_output
            if ! stow_output=$(cd "$base_dir" && stow "${stow_opts[@]}" "$pkg" 2>&1); then
                log_error "  Failed to stow: $pkg"
                local error_output
                error_output=$(echo "$stow_output" | grep -v "^LINK:")
                [[ -n "$error_output" ]] && echo "$error_output"
                return 1
            fi
            # Show non-LINK output if any
            local filtered_output
            filtered_output=$(echo "$stow_output" | grep -v "^LINK:")
            [[ -n "$filtered_output" ]] && echo "$filtered_output"
        else
            # Check if there's a similar file/directory that might be misplaced
            if [[ -e "$base_dir/$pkg-config" ]] || [[ -e "$base_dir/${pkg}_config" ]]; then
                log_warn "  Package not found: $pkg"
                log_warn "    Found similar file/directory. Stow packages must be directories"
                log_warn "    Expected structure: $pkg/.config/$pkg/config (or similar)"
            elif [[ -f "$base_dir/$pkg" ]]; then
                log_warn "  Package not found: $pkg (found file, expected directory)"
                log_warn "    For config files, use structure: $pkg/.config/$pkg/config"
            else
                log_warn "  Package not found: $pkg (directory doesn't exist)"
            fi
        fi
    done

    return 0
}

# Deploy base dotfiles
deploy_base() {
    log_info "Deploying base dotfiles from $DOTFILES_DIR..."

    if [[ ! -d "$DOTFILES_DIR" ]]; then
        log_error "Cannot access $DOTFILES_DIR"
        exit 1
    fi

    # Check for conflicts first (unless in force/adopt mode)
    if [[ "${FORCE_MODE:-false}" != "true" && "${ADOPT_MODE:-false}" != "true" ]]; then
        if ! check_all_conflicts "$DOTFILES_DIR" "${PACKAGES[@]}"; then
            exit 1
        fi
    fi

    # Handle conflicts if in force mode
    if [[ "${FORCE_MODE:-false}" == "true" ]]; then
        log_info "Force mode: removing conflicting files..."
        handle_conflicts "$DOTFILES_DIR" "${PACKAGES[@]}"
    fi

    # Deploy packages
    if ! deploy_packages "$DOTFILES_DIR" "${PACKAGES[@]}"; then
        exit 1
    fi
}

# Deploy work overlay (if present)
deploy_work() {
    if [[ -d "$WORK_DOTFILES_DIR" ]]; then
        log_info "Deploying work overlay from $WORK_DOTFILES_DIR..."

        # Check for conflicts (work overlay adds files, shouldn't conflict much)
        if [[ "${FORCE_MODE:-false}" != "true" && "${ADOPT_MODE:-false}" != "true" ]]; then
            if ! check_all_conflicts "$WORK_DOTFILES_DIR" "${PACKAGES[@]}"; then
                log_warn "Work overlay has conflicts. Skipping work overlay deployment."
                return 1
            fi
        fi

        # Handle conflicts if in force mode
        if [[ "${FORCE_MODE:-false}" == "true" ]]; then
            handle_conflicts "$WORK_DOTFILES_DIR" "${PACKAGES[@]}"
        fi

        # Deploy packages
        if ! deploy_packages "$WORK_DOTFILES_DIR" "${PACKAGES[@]}"; then
            return 1
        fi
    else
        log_info "Work dotfiles not found at $WORK_DOTFILES_DIR (skipping)"
        log_info "To install work overlay later:"
        log_info "  git clone <work-repo-url> $WORK_DOTFILES_DIR"
        log_info "  cd $WORK_DOTFILES_DIR && stow -v -t ~ zsh git nvim ssh"
    fi
}
