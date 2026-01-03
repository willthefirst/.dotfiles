#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Stow deployment logic
# =============================================================================
# Error handling conventions:
#   - Check functions (is_*, has_*) return 0/1, no logging
#   - User-facing functions log errors before returning non-zero
#   - Data-returning functions output to stdout, errors to stderr
# =============================================================================

# Filter out LINK: lines from stow output (verbose info we don't need)
filter_stow_output() {
    grep -v "^LINK:" || true
}

# Create required directories with proper permissions
# Returns: 0 on success, 1 on failure
create_directories() {
    if ! mkdir -p "$HOME/.config"; then
        log_error "Failed to create ~/.config"
        return 1
    fi
    if ! mkdir -p "$HOME/.ssh/sockets"; then
        log_error "Failed to create ~/.ssh/sockets"
        return 1
    fi
    chmod 700 "$HOME/.ssh" 2>/dev/null || true
    chmod 700 "$HOME/.ssh/sockets" 2>/dev/null || true
    return 0
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
# Usage: deploy_packages base_dir adopt_mode package1 package2 ...
# Parameters:
#   base_dir    - directory containing stow packages
#   adopt_mode  - "true" to adopt existing files into stow
deploy_packages() {
    local base_dir="$1"
    local adopt_mode="$2"
    shift 2
    local packages=("$@")
    local stow_opts=(-v -t "$HOME" --no-folding --ignore='deps.*' --ignore='install\.sh')
    local stowed_pkgs=()
    local missing_pkgs=()

    if [[ "$adopt_mode" == "true" ]]; then
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
# Usage: deploy_base [force_mode] [adopt_mode]
# Parameters:
#   force_mode  - "true" to remove conflicts before stowing
#   adopt_mode  - "true" to adopt existing files into stow
deploy_base() {
    local force_mode="${1:-false}"
    local adopt_mode="${2:-false}"

    if [[ ! -d "$DOTFILES_DIR" ]]; then
        log_error "Cannot access $DOTFILES_DIR"
        exit 1
    fi

    # Check for conflicts first (unless in force/adopt mode)
    # shellcheck disable=SC2153
    if [[ "$force_mode" != "true" && "$adopt_mode" != "true" ]]; then
        if ! check_all_conflicts "$DOTFILES_DIR" "${PACKAGES[@]}"; then
            exit 1
        fi
    fi

    # Handle conflicts if in force mode
    if [[ "$force_mode" == "true" ]]; then
        handle_conflicts --force "$DOTFILES_DIR" "${PACKAGES[@]}"
    fi

    # Deploy packages
    if ! deploy_packages "$DOTFILES_DIR" "$adopt_mode" "${PACKAGES[@]}"; then
        exit 1
    fi
}
