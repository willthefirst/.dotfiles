#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Stow deployment logic
# =============================================================================

# Filter out LINK: lines from stow output (verbose info we don't need)
filter_stow_output() {
    grep -v "^LINK:" || true
}

# Create required directories with proper permissions
create_directories() {
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
}

# Deploy packages using stow
# Usage: deploy_packages base_dir package1 package2 ...
deploy_packages() {
    local base_dir="$1"
    shift
    local packages=("$@")
    local stow_opts=(-v -t "$HOME" --no-folding --ignore='deps.*' --ignore='install\.sh')
    local stowed_pkgs=()
    local missing_pkgs=()

    if [[ "${ADOPT_MODE:-false}" == "true" ]]; then
        stow_opts+=(--adopt)
        log_step "Adopt mode enabled"
    fi

    for pkg in "${packages[@]}"; do
        if [[ -d "$base_dir/$pkg" ]]; then
            local stow_output filtered_output
            if ! stow_output=$(cd "$base_dir" && stow "${stow_opts[@]}" "$pkg" 2>&1); then
                log_error "$pkg"
                filtered_output=$(echo "$stow_output" | filter_stow_output)
                [[ -n "$filtered_output" ]] && echo "$filtered_output"
                return 1
            fi
            stowed_pkgs+=("$pkg")
        else
            missing_pkgs+=("$pkg")
        fi
    done

    # Show stowed packages
    if [[ ${#stowed_pkgs[@]} -gt 0 ]]; then
        log_ok "${stowed_pkgs[*]}"
    fi

    # Show missing packages
    for pkg in "${missing_pkgs[@]}"; do
        log_warn "Package not found: $pkg"
    done

    return 0
}

# Deploy base dotfiles
deploy_base() {
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
