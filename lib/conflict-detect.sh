#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# lib/conflict-detect.sh - Conflict detection logic for stow packages
# =============================================================================
# Dependencies: conflict-data.sh, fs.sh
# Provides: get_package_conflicts, report_symlink_mismatch, is_already_checked,
#           check_directory_conflict, check_parent_symlink, check_file_conflict
# =============================================================================

# Source guard - prevent multiple loading
[[ -n "${_DOTFILES_CONFLICT_DETECT_LOADED:-}" ]] && return 0
_DOTFILES_CONFLICT_DETECT_LOADED=1

# Source dependencies
# shellcheck source=lib/conflict-data.sh
source "${BASH_SOURCE%/*}/conflict-data.sh"
# shellcheck source=lib/fs.sh
source "${BASH_SOURCE%/*}/fs.sh"

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

# =============================================================================
# Main detection function
# =============================================================================

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
