#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# lib/conflict-resolve.sh - Conflict resolution and user-facing reporting
# =============================================================================
# Dependencies: conflict-data.sh, conflict-detect.sh, log.sh, config.sh
# Provides: check_all_conflicts, remove_conflict, is_under_removed_path,
#           handle_conflicts
# =============================================================================

# Source guard - prevent multiple loading
[[ -n "${_DOTFILES_CONFLICT_RESOLVE_LOADED:-}" ]] && return 0
_DOTFILES_CONFLICT_RESOLVE_LOADED=1

# Source dependencies
# shellcheck source=lib/conflict-data.sh
source "${BASH_SOURCE%/*}/conflict-data.sh"
# shellcheck source=lib/conflict-detect.sh
source "${BASH_SOURCE%/*}/conflict-detect.sh"
# shellcheck source=lib/log.sh
source "${BASH_SOURCE%/*}/log.sh"
# shellcheck source=lib/config.sh
source "${BASH_SOURCE%/*}/config.sh"

# =============================================================================
# Conflict reporting
# =============================================================================

# Check all packages for conflicts and report them
# Returns 0 if no conflicts, 1 if conflicts found
check_all_conflicts() {
    local base_dir="$1"
    shift
    local packages=("$@")
    local all_conflicts=()

    for pkg in "${packages[@]}"; do
        local pkg_dir="$base_dir/$pkg"
        if [[ -d "$pkg_dir" ]]; then
            while IFS= read -r conflict; do
                [[ -n "$conflict" ]] && all_conflicts+=("$pkg:$conflict")
            done < <(get_package_conflicts "$pkg_dir" "$DOTFILES_HOME")
        fi
    done

    if [[ ${#all_conflicts[@]} -gt 0 ]]; then
        echo ""
        log_error "Conflicts detected that would prevent stow from running:"
        echo ""

        local current_pkg=""
        for conflict in "${all_conflicts[@]}"; do
            local pkg="${conflict%%:*}"
            local rest="${conflict#*:}"
            local type path target

            type=$(parse_conflict_type "$rest")
            path=$(parse_conflict_path "$rest")

            if [[ "$pkg" != "$current_pkg" ]]; then
                [[ -n "$current_pkg" ]] && echo ""
                log_warn "[$pkg]"
                current_pkg="$pkg"
            fi

            if [[ "$type" == "$CONFLICT_TYPE_SYMLINK" ]]; then
                target=$(parse_conflict_target "$rest")
                log_error "  $path"
                log_info "    -> symlink to $target (not managed by stow)"
            else
                log_error "  $path"
                log_info "    -> regular file/directory (would be overwritten)"
            fi
        done

        echo ""
        log_info "-------------------------------------------------------------------"
        log_warn "How to resolve:"
        echo ""
        log_info "Option 1: Remove conflicting symlinks/files automatically"
        log_step "make configure-force"
        echo ""
        log_info "Option 2: Adopt existing files into stow (keeps current content)"
        log_step "make configure-adopt"
        echo ""
        log_info "Option 3: Remove manually, then re-run:"
        for conflict in "${all_conflicts[@]}"; do
            local path
            path=$(parse_conflict_path "$conflict")
            log_info "  rm \"$path\""
        done
        log_info "  make configure"
        log_info "-------------------------------------------------------------------"
        echo ""

        return 1
    fi

    return 0
}

# =============================================================================
# Conflict resolution
# =============================================================================

# Remove a conflicting path (file, directory, or symlink)
# Usage: remove_conflict "/path/to/conflict"
remove_conflict() {
    local path="$1"
    local short_path="${path#"$DOTFILES_HOME/"}"

    if [[ -e "$path" || -L "$path" ]]; then
        log_step "Removing conflict: ~/$short_path"
        rm -rf "$path"
    fi
}

# Check if path is under any of the removed paths
# Usage: is_under_removed_path "/path" "${removed_paths[@]}"
is_under_removed_path() {
    local path="$1"
    shift
    local removed=("$@")
    for removed_path in "${removed[@]}"; do
        if [[ "$path" == "$removed_path"* ]]; then
            return 0
        fi
    done
    return 1
}

# Handle conflicts by removing conflicting files
# Usage: handle_conflicts [--force] base_dir package1 package2 ...
# Options:
#   --force  Actually remove conflicts (required, acts as safety check)
handle_conflicts() {
    local force_mode=false
    if [[ "${1:-}" == "--force" ]]; then
        force_mode=true
        shift
    fi

    local base_dir="$1"
    shift
    local packages=("$@")
    local removed_paths=()

    # Safety: only proceed if --force was explicitly passed
    $force_mode || return 0

    for pkg in "${packages[@]}"; do
        local pkg_dir="$base_dir/$pkg"
        [[ ! -d "$pkg_dir" ]] && continue

        while IFS= read -r conflict; do
            [[ -z "$conflict" ]] && continue

            local path
            path=$(parse_conflict_path "$conflict")

            # Safety check: never remove with empty path
            if [[ -z "$path" ]]; then
                log_error "Empty path - aborting removal"
                continue
            fi

            # Skip if already removed (parent directory was removed)
            is_under_removed_path "$path" "${removed_paths[@]}" && continue

            remove_conflict "$path"
            removed_paths+=("$path")
        done < <(get_package_conflicts "$pkg_dir" "$DOTFILES_HOME")
    done
}
