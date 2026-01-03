#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Dependency installation module for dotfiles
# =============================================================================
# Installs actual programs (not just their configs) using system package managers.
# Supports per-package dependency specification via deps files and custom install scripts.
#
# PACKAGE DEPENDENCY INTERFACE
# ============================
# Each package directory can define dependencies in three ways:
#
# 1. deps file - Common dependencies (all platforms)
#    Location: <package>/deps
#    Format: One package name per line, # comments allowed
#    Example:
#      ripgrep
#      fd  # file finder
#
# 2. Platform-specific deps files
#    Location: <package>/deps.darwin (macOS) or <package>/deps.linux
#    Format: Same as deps file
#    For Homebrew casks: prefix with "--cask " (e.g., "--cask font-fira-code")
#
# 3. Custom install script
#    Location: <package>/install.sh
#    Must define: install_<package>() function
#    Example for "git" package - define install_git() in git/install.sh
#    The function should return 0 on success, non-zero on failure.
#
# EXECUTION ORDER
# ===============
# 1. Custom install.sh (if exists)
# 2. Common deps file
# 3. Platform-specific deps file
#
# This order allows install.sh to set up prerequisites before deps are installed.
# =============================================================================

# =============================================================================
# Package manager abstraction
# =============================================================================

# Install packages using the system package manager
# Usage: pkg_install <packages...>
# Note: On macOS, packages starting with "--cask" are installed as casks
pkg_install() {
    local packages=("$@")
    [[ ${#packages[@]} -eq 0 ]] && return 0

    if is_macos; then
        local regular_pkgs=()
        local cask_pkgs=()
        local is_cask=false

        for pkg in "${packages[@]}"; do
            if [[ "$pkg" == "--cask" ]]; then
                is_cask=true
                continue
            fi
            if $is_cask; then
                cask_pkgs+=("$pkg")
                is_cask=false
            else
                regular_pkgs+=("$pkg")
            fi
        done

        [[ ${#regular_pkgs[@]} -gt 0 ]] && brew install "${regular_pkgs[@]}"
        [[ ${#cask_pkgs[@]} -gt 0 ]] && brew install --cask "${cask_pkgs[@]}"
        return 0
    elif is_linux; then
        sudo apt update
        sudo apt install -y "${packages[@]}"
    else
        log_error "Unsupported platform: $(uname -s)"
        return 1
    fi
}

# Check if a package is installed via the system package manager
# Usage: pkg_installed <package>
# Returns 0 if installed, 1 if not
pkg_installed() {
    local pkg="$1"

    if is_macos; then
        brew list "$pkg" &>/dev/null || brew list --cask "$pkg" &>/dev/null
    elif is_linux; then
        dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"
    else
        return 1
    fi
}

# =============================================================================
# Utility helpers
# =============================================================================

# Check if a command exists in PATH
# Usage: has_command <cmd>
# Returns 0 if exists, 1 if not
has_command() {
    command -v "$1" &>/dev/null
}

# Create directory if it doesn't exist
# Usage: ensure_dir <path>
ensure_dir() {
    local path="$1"
    [[ -d "$path" ]] || mkdir -p "$path"
}

# =============================================================================
# Dependency file parsing
# =============================================================================

# Read packages from a deps file (one package per line)
# Usage: read_deps_file <file_path>
# Outputs packages to stdout, one per line
# Skips empty lines and comments (lines starting with #)
read_deps_file() {
    local file="$1"
    [[ -f "$file" ]] || return 0

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        line="${line%%#*}"  # Remove comments
        line="${line#"${line%%[![:space:]]*}"}"  # Trim leading whitespace
        line="${line%"${line##*[![:space:]]}"}"  # Trim trailing whitespace
        [[ -n "$line" ]] && echo "$line"
    done < "$file"
}

# Get platform-specific deps file suffix
# Usage: get_platform_suffix
# Outputs: "darwin" or "linux"
get_platform_suffix() {
    if is_macos; then
        echo "darwin"
    elif is_linux; then
        echo "linux"
    fi
}

# =============================================================================
# Main entry points
# =============================================================================

# Install dependencies for a single package
# Usage: install_package_deps <package_name>
# Returns: 0 on success (or skip), 1 on failure
install_package_deps() {
    local pkg="$1"
    local pkg_dir="${DOTFILES_DIR}/${pkg}"
    local platform
    platform=$(get_platform_suffix)
    local had_failure=false

    # Check if package directory exists
    if [[ ! -d "$pkg_dir" ]]; then
        log_warn "Package directory not found: $pkg_dir"
        return 0
    fi

    local has_deps=false
    [[ -f "$pkg_dir/deps" ]] && has_deps=true
    [[ -f "$pkg_dir/deps.$platform" ]] && has_deps=true
    [[ -f "$pkg_dir/install.sh" ]] && has_deps=true

    if ! $has_deps; then
        return 0  # No deps to install, not an error
    fi

    # Step 1: Run custom install.sh if it exists
    if [[ -f "$pkg_dir/install.sh" ]]; then
        local install_func="install_${pkg}"
        # Source the install script
        # shellcheck source=/dev/null
        source "$pkg_dir/install.sh"

        if declare -f "$install_func" >/dev/null; then
            if $DRY_RUN; then
                log_step "$pkg (custom installer, dry-run)"
            elif "$install_func"; then
                log_ok "$pkg (custom)"
            else
                log_error "$pkg (custom installer failed)"
                had_failure=true
            fi
        else
            log_error "$pkg: install.sh exists but missing $install_func() function"
            had_failure=true
        fi
    fi

    # Step 2: Install packages from deps file (common)
    if [[ -f "$pkg_dir/deps" ]]; then
        local common_deps
        common_deps=$(read_deps_file "$pkg_dir/deps")
        if [[ -n "$common_deps" ]]; then
            while IFS= read -r dep; do
                install_single_dep "$dep" || had_failure=true
            done <<< "$common_deps"
        fi
    fi

    # Step 3: Install platform-specific deps
    local platform_file="$pkg_dir/deps.$platform"
    if [[ -f "$platform_file" ]]; then
        local platform_deps
        platform_deps=$(read_deps_file "$platform_file")
        if [[ -n "$platform_deps" ]]; then
            while IFS= read -r dep; do
                install_single_dep "$dep" || had_failure=true
            done <<< "$platform_deps"
        fi
    fi

    $had_failure && return 1
    return 0
}

# Install a single dependency
# Usage: install_single_dep <dep>
# Returns: 0 on success, 1 on failure
install_single_dep() {
    local dep="$1"

    # Handle --cask prefix for brew
    local check_dep="$dep"
    if [[ "$dep" == "--cask "* ]]; then
        check_dep="${dep#--cask }"
    fi

    # Check dry-run first to avoid slow brew calls in tests
    if $DRY_RUN; then
        log_step "$dep (dry-run)"
        return 0
    fi

    # Check if already installed
    if pkg_installed "$check_dep" || has_command "$check_dep"; then
        log_ok "$check_dep"
        return 0
    fi

    # shellcheck disable=SC2086
    if pkg_install $dep >/dev/null 2>&1; then
        log_ok "$dep"
        return 0
    else
        log_error "$dep"
        return 1
    fi
}

# Install dependencies for multiple packages
# Usage: install_all_deps <packages...>
# Returns: 0 if all succeed, 1 if any fail
install_all_deps() {
    local packages=("$@")
    local any_failed=false

    # Verify package manager is available
    if is_macos; then
        if ! has_command brew; then
            log_error "Homebrew not installed (https://brew.sh)"
            return 1
        fi
    elif is_linux; then
        if ! has_command apt; then
            log_error "apt not available (requires Debian/Ubuntu)"
            return 1
        fi
    fi

    log_section "Installing programs..."

    for pkg in "${packages[@]}"; do
        if ! install_package_deps "$pkg"; then
            any_failed=true
        fi
    done

    if $any_failed; then
        log_warn "Some dependencies failed"
        return 1
    fi
    return 0
}

# =============================================================================
# Dry-run mode (for testing)
# =============================================================================
DRY_RUN=${DRY_RUN:-false}

# Enable dry-run mode
# Usage: deps_dry_run_enable
deps_dry_run_enable() {
    DRY_RUN=true
}

# Disable dry-run mode
# Usage: deps_dry_run_disable
deps_dry_run_disable() {
    DRY_RUN=false
}
