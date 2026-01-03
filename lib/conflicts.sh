#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Conflict detection and resolution for stow packages
# =============================================================================
# Error handling conventions:
#   - Check functions (is_*, has_*) return 0/1, no logging
#   - User-facing functions log errors before returning non-zero
#   - Data-returning functions output to stdout, errors to stderr
# =============================================================================

# =============================================================================
# Conflict string format: "type:path[:target]"
#   - type: "file" or "symlink"
#   - path: the conflicting path
#   - target: symlink target (only for symlink type)
# With package prefix: "pkg:type:path[:target]"
# =============================================================================

# Guard against re-sourcing (readonly variables can't be redeclared)
[[ -n "${_CONFLICTS_SH_LOADED:-}" ]] && return 0
_CONFLICTS_SH_LOADED=true

# Conflict type constants
readonly CONFLICT_TYPE_FILE="file"
readonly CONFLICT_TYPE_SYMLINK="symlink"

# =============================================================================
# Conflict string constructors (preferred over inline string building)
# =============================================================================

# Create a file conflict string
# Usage: make_file_conflict "/path/to/file"
# Output: "file:/path/to/file"
make_file_conflict() {
    echo "${CONFLICT_TYPE_FILE}:$1"
}

# Create a symlink conflict string
# Usage: make_symlink_conflict "/path/to/link" "/actual/target"
# Output: "symlink:/path/to/link:/actual/target"
make_symlink_conflict() {
    echo "${CONFLICT_TYPE_SYMLINK}:$1:$2"
}

# =============================================================================
# Conflict string parsers
# =============================================================================

# Parse conflict type from string
# Usage: parse_conflict_type "type:path[:target]" or "pkg:type:path[:target]"
# Output: "file" or "symlink"
parse_conflict_type() {
    local conflict="$1"
    local first="${conflict%%:*}"

    # If first field is a known type, return it
    if [[ "$first" == "$CONFLICT_TYPE_FILE" || "$first" == "$CONFLICT_TYPE_SYMLINK" ]]; then
        echo "$first"
        return
    fi

    # Otherwise first field is pkg, type is second field
    local rest="${conflict#*:}"
    echo "${rest%%:*}"
}

# Parse conflict path from string
# Usage: parse_conflict_path "type:path[:target]" or "pkg:type:path[:target]"
# Output: the path component
parse_conflict_path() {
    local conflict="$1"
    local first="${conflict%%:*}"
    local rest="${conflict#*:}"

    # If first field is a type, path is second field
    if [[ "$first" == "$CONFLICT_TYPE_FILE" || "$first" == "$CONFLICT_TYPE_SYMLINK" ]]; then
        echo "${rest%%:*}"
        return
    fi

    # First field is pkg, skip it and the type
    rest="${rest#*:}"  # Skip type field
    echo "${rest%%:*}"
}

# Parse symlink target from conflict string (symlink conflicts only)
# Usage: parse_conflict_target "symlink:path:target" or "pkg:symlink:path:target"
# Output: the target, or empty string if not a symlink conflict
parse_conflict_target() {
    local conflict="$1"
    local type
    type=$(parse_conflict_type "$conflict")

    if [[ "$type" != "$CONFLICT_TYPE_SYMLINK" ]]; then
        return
    fi

    # Target is the last colon-separated field
    echo "${conflict##*:}"
}

# =============================================================================
# Conflict detection helpers
# =============================================================================

# Report symlink conflict if symlink doesn't match expected target
# Usage: report_symlink_mismatch target_path expected_target
# Outputs: conflict string if mismatch, nothing if matches
report_symlink_mismatch() {
    local target_path="$1"
    local expected_target="$2"
    if ! symlink_matches "$target_path" "$expected_target"; then
        make_symlink_conflict "$target_path" "$(readlink "$target_path")"
    fi
}

# Check if a path is already in the checked array
# Usage: is_already_checked "path" "${checked_array[@]}"
is_already_checked() {
    local path="$1"
    shift
    local checked=("$@")
    for item in "${checked[@]}"; do
        if [[ "$path" == "$item" ]]; then
            return 0
        fi
    done
    return 1
}

# Check directory for conflicts (handles directory symlinks)
# Usage: check_directory_conflict pkg_dir target_path rel_path
# Outputs conflict string if found
check_directory_conflict() {
    local pkg_dir="$1"
    local target_path="$2"
    local rel_path="$3"

    if [[ -L "$target_path" ]]; then
        report_symlink_mismatch "$target_path" "$pkg_dir/$rel_path"
    elif [[ -e "$target_path" && ! -d "$target_path" ]]; then
        make_file_conflict "$target_path"
    fi
}

# Status constants for check_parent_symlink
readonly PARENT_STATUS_MANAGED="managed"
readonly PARENT_STATUS_ALREADY_REPORTED="already_reported"

# Check file for parent symlink conflicts
# Usage: check_parent_symlink pkg_dir target_dir target_path checked_dirs_ref
# Returns: "managed", "already_reported", or symlink conflict string
check_parent_symlink() {
    local pkg_dir="$1"
    local target_dir="$2"
    local target_path="$3"
    shift 3
    local checked_dirs=("$@")

    local parent_path="$target_path"
    while [[ "$parent_path" != "$target_dir" ]]; do
        parent_path=$(dirname "$parent_path")
        if [[ -L "$parent_path" ]]; then
            local parent_rel="${parent_path#"$target_dir"/}"
            local expected_parent="$pkg_dir/$parent_rel"

            if symlink_matches "$parent_path" "$expected_parent"; then
                echo "$PARENT_STATUS_MANAGED"
            elif ! is_already_checked "$parent_path" "${checked_dirs[@]}"; then
                make_symlink_conflict "$parent_path" "$(readlink "$parent_path")"
            else
                echo "$PARENT_STATUS_ALREADY_REPORTED"
            fi
            return
        fi
    done
}

# Check file for direct conflicts
# Usage: check_file_conflict pkg_dir target_path rel_path
# Outputs conflict string if found
check_file_conflict() {
    local pkg_dir="$1"
    local target_path="$2"
    local rel_path="$3"

    if [[ -L "$target_path" ]]; then
        report_symlink_mismatch "$target_path" "$pkg_dir/$rel_path"
    elif [[ -e "$target_path" ]]; then
        make_file_conflict "$target_path"
    fi
}

# Returns list of conflicting files for a given stow package
# Output format: type:path[:target] (e.g., "symlink:/path:target" or "file:/path")
get_package_conflicts() {
    local pkg_dir="$1"
    local target_dir="$2"
    local conflicts=()
    local checked_dirs=()

    if [[ ! -d "$pkg_dir" ]]; then
        return
    fi

    while IFS= read -r -d '' item; do
        local rel_path="${item#"$pkg_dir"/}"
        local target_path="$target_dir/$rel_path"

        if [[ -d "$item" ]]; then
            # Directory: check for conflicting symlink
            local conflict
            conflict=$(check_directory_conflict "$pkg_dir" "$target_path" "$rel_path")
            if [[ -n "$conflict" ]] && ! is_already_checked "$target_path" "${checked_dirs[@]}"; then
                conflicts+=("$conflict")
                checked_dirs+=("$target_path")
            fi
        else
            # File: check parent directories first, then the file itself
            local parent_result
            parent_result=$(check_parent_symlink "$pkg_dir" "$target_dir" "$target_path" "${checked_dirs[@]}")

            case "$parent_result" in
                "$PARENT_STATUS_MANAGED"|"$PARENT_STATUS_ALREADY_REPORTED")
                    # Skip - already handled
                    ;;
                "$CONFLICT_TYPE_SYMLINK":*)
                    # Parent symlink is a conflict - result is already formatted
                    local parent_path
                    parent_path=$(parse_conflict_path "$parent_result")
                    conflicts+=("$parent_result")
                    checked_dirs+=("$parent_path")
                    ;;
                *)
                    # No parent conflict - check file directly
                    local conflict
                    conflict=$(check_file_conflict "$pkg_dir" "$target_path" "$rel_path")
                    if [[ -n "$conflict" ]]; then
                        conflicts+=("$conflict")
                    fi
                    ;;
            esac
        fi
    done < <(find "$pkg_dir" -mindepth 1 \( -type f -o -type d \) -print0 2>/dev/null)

    printf '%s\n' "${conflicts[@]}"
}

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
            done < <(get_package_conflicts "$pkg_dir" "$HOME")
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

# Remove a conflicting path (file, directory, or symlink)
# Usage: remove_conflict "/path/to/conflict"
remove_conflict() {
    local path="$1"
    local short_path="${path#"$HOME/"}"

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
        done < <(get_package_conflicts "$pkg_dir" "$HOME")
    done
}
