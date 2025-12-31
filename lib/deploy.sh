#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Stow deployment logic
# =============================================================================

# Create required directories with proper permissions
create_directories() {
    mkdir -p "$HOME/.config"
    mkdir -p "$HOME/.ssh/sockets"
    chmod 700 "$HOME/.ssh"
    chmod 700 "$HOME/.ssh/sockets"
    echo "✓ Directories created"
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
    echo "✓ GNU Stow found"
}

# Deploy packages using stow
# Usage: deploy_packages base_dir package1 package2 ...
deploy_packages() {
    local base_dir="$1"
    shift
    local packages=("$@")
    local stow_opts=(-v -t "$HOME")
    local stowed_pkgs=()
    local missing_pkgs=()

    if [[ "${ADOPT_MODE:-false}" == "true" ]]; then
        stow_opts+=(--adopt)
        log_info "Adopt mode: existing files will be adopted into stow packages"
    fi

    for pkg in "${packages[@]}"; do
        if [[ -d "$base_dir/$pkg" ]]; then
            local stow_output
            if ! stow_output=$(cd "$base_dir" && stow "${stow_opts[@]}" "$pkg" 2>&1); then
                echo -e "  ${RED}✗${NC} Failed to stow: $pkg"
                local error_output
                error_output=$(echo "$stow_output" | grep -v "^LINK:")
                [[ -n "$error_output" ]] && echo "$error_output"
                return 1
            fi
            stowed_pkgs+=("$pkg")
            # Show non-LINK output if any
            local filtered_output
            filtered_output=$(echo "$stow_output" | grep -v "^LINK:")
            [[ -n "$filtered_output" ]] && echo "$filtered_output"
        else
            missing_pkgs+=("$pkg")
        fi
    done

    # Show summary
    if [[ ${#stowed_pkgs[@]} -gt 0 ]]; then
        echo "  Stowing: ${stowed_pkgs[*]}"
    fi

    # Show missing packages
    for pkg in "${missing_pkgs[@]}"; do
        echo -e "  ${YELLOW}⚠${NC} Package not found: $pkg"
    done

    return 0
}

# Deploy base dotfiles
deploy_base() {
    echo ""
    echo "Deploying base dotfiles..."

    if [[ ! -d "$DOTFILES_DIR" ]]; then
        log_error "Cannot access $DOTFILES_DIR"
        exit 1
    fi

    # Check for conflicts first (unless in force/adopt mode)
    # shellcheck disable=SC2153
    if [[ "${FORCE_MODE:-false}" != "true" && "${ADOPT_MODE:-false}" != "true" ]]; then
        if ! check_all_conflicts "$DOTFILES_DIR" "${PACKAGES[@]}"; then
            exit 1
        fi
    fi

    # Handle conflicts if in force mode
    if [[ "${FORCE_MODE:-false}" == "true" ]]; then
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
        echo ""
        echo "Deploying work overlay..."

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
    fi
}
