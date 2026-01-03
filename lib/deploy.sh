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

# Guard against re-sourcing (readonly variables can't be redeclared)
[[ -n "${_DEPLOY_SH_LOADED:-}" ]] && return 0
_DEPLOY_SH_LOADED=true

# SSH directory permissions (owner read/write/execute only)
readonly SSH_DIR_PERMISSIONS=700

# Filter out LINK: lines from stow output (verbose info we don't need)
filter_stow_output() {
    grep -v "^LINK:" || true
}

# Create required directories with proper permissions
# Returns: 0 on success, 1 on failure
create_directories() {
    if ! mkdir -p "$DOTFILES_CONFIG_DIR"; then
        log_error "Failed to create $DOTFILES_CONFIG_DIR"
        return 1
    fi
    if ! mkdir -p "$DOTFILES_SSH_DIR/sockets"; then
        log_error "Failed to create $DOTFILES_SSH_DIR/sockets"
        return 1
    fi
    chmod "$SSH_DIR_PERMISSIONS" "$DOTFILES_SSH_DIR" 2>/dev/null || true
    chmod "$SSH_DIR_PERMISSIONS" "$DOTFILES_SSH_DIR/sockets" 2>/dev/null || true
    return 0
}

# Check prerequisites (GNU Stow) - auto-install if missing
check_prerequisites() {
    if command -v stow &>/dev/null; then
        return 0
    fi

    log_step "Installing stow..."
    if pkg_install stow; then
        log_ok "stow"
    else
        log_error "Failed to install stow"
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
    local stow_opts=(-v -t "$DOTFILES_HOME" --no-folding --ignore='deps.*' --ignore='install\.sh')
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
