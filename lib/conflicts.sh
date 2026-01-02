#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Conflict detection and resolution for stow packages
# =============================================================================

# Report symlink conflict if symlink doesn't match expected target
# Usage: report_symlink_mismatch target_path expected_target
# Outputs: "symlink:path:actual_target" if mismatch, nothing if matches
report_symlink_mismatch() {
    local target_path="$1"
    local expected_target="$2"
    if ! symlink_matches "$target_path" "$expected_target"; then
        echo "symlink:$target_path:$(readlink "$target_path")"
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
        echo "file:$target_path"
    fi
}

# Check file for parent symlink conflicts
# Usage: check_parent_symlink pkg_dir target_dir target_path checked_dirs_ref
# Returns: "managed" if managed by parent, "conflict:path:target" if conflict, "" if none
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
                echo "managed"
            elif ! is_already_checked "$parent_path" "${checked_dirs[@]}"; then
                echo "conflict:$parent_path:$(readlink "$parent_path")"
            else
                echo "already_reported"
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
        echo "file:$target_path"
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
                managed|already_reported)
                    # Skip - already handled
                    ;;
                conflict:*)
                    # Parent symlink is a conflict
                    local parent_path="${parent_result#conflict:}"
                    parent_path="${parent_path%%:*}"
                    conflicts+=("symlink:${parent_result#conflict:}")
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
            local type="${rest%%:*}"
            local path="${rest#*:}"

            if [[ "$pkg" != "$current_pkg" ]]; then
                [[ -n "$current_pkg" ]] && echo ""
                echo -e "  ${YELLOW}[$pkg]${NC}"
                current_pkg="$pkg"
            fi

            if [[ "$type" == "symlink" ]]; then
                local target="${path#*:}"
                path="${path%%:*}"
                echo -e "    ${RED}*${NC} $path"
                echo -e "      -> symlink to $target (not managed by stow)"
            else
                echo -e "    ${RED}*${NC} $path"
                echo -e "      -> regular file/directory (would be overwritten)"
            fi
        done

        echo ""
        echo "-------------------------------------------------------------------"
        echo -e "${YELLOW}How to resolve:${NC}"
        echo ""
        echo "  Option 1: Remove conflicting symlinks/files automatically"
        echo -e "    ${GREEN}make install-force${NC}"
        echo ""
        echo "  Option 2: Adopt existing files into stow (keeps current content)"
        echo -e "    ${GREEN}make install-adopt${NC}"
        echo ""
        echo "  Option 3: Remove manually, then re-run:"
        for conflict in "${all_conflicts[@]}"; do
            local rest="${conflict#*:}"
            local path="${rest#*:}"
            path="${path%%:*}"
            echo "    rm \"$path\""
        done
        echo "    make install"
        echo "-------------------------------------------------------------------"
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

    if [[ -L "$path" ]]; then
        echo "  Removing conflict: ~/$short_path"
        rm "$path"
    elif [[ -d "$path" ]]; then
        echo "  Removing conflict: ~/$short_path"
        rm -rf "$path"
    elif [[ -f "$path" ]]; then
        echo "  Removing conflict: ~/$short_path"
        rm "$path"
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

# Handle conflicts based on mode (--force)
# Requires FORCE_MODE to be set
handle_conflicts() {
    local base_dir="$1"
    shift
    local packages=("$@")
    local removed_paths=()

    [[ "${FORCE_MODE:-false}" != "true" ]] && return

    for pkg in "${packages[@]}"; do
        local pkg_dir="$base_dir/$pkg"
        [[ ! -d "$pkg_dir" ]] && continue

        while IFS= read -r conflict; do
            [[ -z "$conflict" ]] && continue

            local path="${conflict#*:}"
            path="${path%%:*}"

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
