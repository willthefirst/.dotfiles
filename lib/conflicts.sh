#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Conflict detection and resolution for stow packages
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

    # Find all files and directories that stow would manage
    while IFS= read -r -d '' item; do
        local rel_path="${item#"$pkg_dir"/}"
        local target_path="$target_dir/$rel_path"

        # For directories, check if there's a conflicting symlink at that path
        if [[ -d "$item" ]]; then
            if [[ -L "$target_path" ]]; then
                local expected_target="$pkg_dir/$rel_path"
                local actual_target
                actual_target=$(readlink -f "$target_path" 2>/dev/null || echo "")
                local expected_resolved
                expected_resolved=$(readlink -f "$expected_target" 2>/dev/null || echo "$expected_target")

                if [[ "$actual_target" != "$expected_resolved" ]]; then
                    # Check if we already reported this
                    local already_reported=false
                    for checked in "${checked_dirs[@]}"; do
                        if [[ "$target_path" == "$checked" ]]; then
                            already_reported=true
                            break
                        fi
                    done
                    if ! $already_reported; then
                        conflicts+=("symlink:$target_path:$(readlink "$target_path")")
                        checked_dirs+=("$target_path")
                    fi
                fi
            elif [[ -e "$target_path" && ! -d "$target_path" ]]; then
                # A file exists where a directory should be
                conflicts+=("file:$target_path")
            fi
        else
            # It's a file - check if any parent directory is a symlink
            local parent_path="$target_path"
            local parent_conflict=false
            local parent_is_managed=false
            while [[ "$parent_path" != "$target_dir" ]]; do
                parent_path=$(dirname "$parent_path")
                if [[ -L "$parent_path" ]]; then
                    # Parent is a symlink - check if it's correctly managed by stow
                    local parent_rel="${parent_path#"$target_dir"/}"
                    local expected_parent="$pkg_dir/$parent_rel"
                    local actual_parent
                    actual_parent=$(readlink -f "$parent_path" 2>/dev/null || echo "")
                    local expected_parent_resolved
                    expected_parent_resolved=$(readlink -f "$expected_parent" 2>/dev/null || echo "$expected_parent")

                    if [[ "$actual_parent" == "$expected_parent_resolved" ]]; then
                        # Parent symlink is correct - file is already managed
                        parent_is_managed=true
                    else
                        # Parent symlink points elsewhere - check if already reported
                        for checked in "${checked_dirs[@]}"; do
                            if [[ "$parent_path" == "$checked" ]]; then
                                parent_conflict=true
                                break
                            fi
                        done
                        if ! $parent_conflict; then
                            conflicts+=("symlink:$parent_path:$(readlink "$parent_path")")
                            checked_dirs+=("$parent_path")
                            parent_conflict=true
                        fi
                    fi
                    break
                fi
            done

            # Only check the file itself if no parent conflict and not already managed
            if ! $parent_conflict && ! $parent_is_managed; then
                if [[ -L "$target_path" ]]; then
                    local expected_target="$pkg_dir/$rel_path"
                    local actual_target
                    actual_target=$(readlink -f "$target_path" 2>/dev/null || echo "")
                    local expected_resolved
                    expected_resolved=$(readlink -f "$expected_target" 2>/dev/null || echo "$expected_target")

                    if [[ "$actual_target" != "$expected_resolved" ]]; then
                        conflicts+=("symlink:$target_path:$(readlink "$target_path")")
                    fi
                elif [[ -e "$target_path" ]]; then
                    conflicts+=("file:$target_path")
                fi
            fi
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
        echo -e "    ${GREEN}./install.sh --force${NC}"
        echo ""
        echo "  Option 2: Adopt existing files into stow (keeps current content)"
        echo -e "    ${GREEN}./install.sh --adopt${NC}"
        echo ""
        echo "  Option 3: Remove manually, then re-run:"
        for conflict in "${all_conflicts[@]}"; do
            local rest="${conflict#*:}"
            local path="${rest#*:}"
            path="${path%%:*}"
            echo "    rm \"$path\""
        done
        echo "    ./install.sh"
        echo "-------------------------------------------------------------------"
        echo ""

        return 1
    fi

    return 0
}

# Handle conflicts based on mode (--force)
# Requires FORCE_MODE to be set
handle_conflicts() {
    local base_dir="$1"
    shift
    local packages=("$@")
    local removed_paths=()

    for pkg in "${packages[@]}"; do
        local pkg_dir="$base_dir/$pkg"
        if [[ -d "$pkg_dir" ]]; then
            while IFS= read -r conflict; do
                [[ -z "$conflict" ]] && continue

                local type="${conflict%%:*}"
                local path="${conflict#*:}"
                path="${path%%:*}"

                # Safety check: never remove with empty path
                if [[ -z "$path" ]]; then
                    log_error "Empty path - aborting removal"
                    continue
                fi

                # Skip if already removed (parent directory was removed)
                local already_removed=false
                for removed in "${removed_paths[@]}"; do
                    if [[ "$path" == "$removed"* ]]; then
                        already_removed=true
                        break
                    fi
                done
                $already_removed && continue

                if [[ "${FORCE_MODE:-false}" == "true" ]]; then
                    local short_path="${path#"$HOME/"}"
                    if [[ -L "$path" ]]; then
                        echo "  Removing conflict: ~/$short_path"
                        rm "$path"
                        removed_paths+=("$path")
                    elif [[ -d "$path" ]]; then
                        echo "  Removing conflict: ~/$short_path"
                        rm -rf "$path"
                        removed_paths+=("$path")
                    elif [[ -f "$path" ]]; then
                        echo "  Removing conflict: ~/$short_path"
                        rm "$path"
                        removed_paths+=("$path")
                    fi
                fi
            done < <(get_package_conflicts "$pkg_dir" "$HOME")
        fi
    done
}
