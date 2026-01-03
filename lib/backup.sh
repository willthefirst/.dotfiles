#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# lib/backup.sh - Backup logic for dotfiles
# =============================================================================
# Dependencies: log.sh, fs.sh, config.sh
# Provides: needs_backup, create_backup
# =============================================================================

# Source guard - prevent multiple loading
[[ -n "${_DOTFILES_BACKUP_LOADED:-}" ]] && return 0
_DOTFILES_BACKUP_LOADED=1

# Source dependencies
# shellcheck source=lib/log.sh
source "${BASH_SOURCE%/*}/log.sh"
# shellcheck source=lib/fs.sh
source "${BASH_SOURCE%/*}/fs.sh"
# shellcheck source=lib/config.sh
source "${BASH_SOURCE%/*}/config.sh"

# Check if any files need backup
# Returns 0 if backup needed, 1 if not
needs_backup() {
    local files=("$@")

    for file in "${files[@]}"; do
        if file_or_link_exists "$file"; then
            # Only backup if it's not already managed by stow
            if ! is_dotfiles_managed "$file"; then
                return 0
            fi
        fi
    done

    return 1
}

# Create timestamped backup of specified files
# Usage: create_backup [--skip] file1 file2 ...
# Options:
#   --skip    Skip backup (used with --force mode)
# Returns: 0 on success, 1 on failure
create_backup() {
    local skip_backup=false
    if [[ "${1:-}" == "--skip" ]]; then
        skip_backup=true
        shift
    fi

    local files=("$@")
    local backup_dir
    backup_dir="$DOTFILES_BACKUP_DIR/${BACKUP_PREFIX}$(date +%Y%m%d-%H%M%S)"

    if ! needs_backup "${files[@]}"; then
        return 0
    fi

    if $skip_backup; then
        return 0
    fi

    if ! mkdir -p "$backup_dir"; then
        log_error "Failed to create backup directory: $backup_dir"
        return 1
    fi

    local backed_up=0
    local failed=0
    for file in "${files[@]}"; do
        if file_or_link_exists "$file" && ! is_dotfiles_managed "$file"; then
            local backup_path
            backup_path="$backup_dir/$(basename "$file")"
            # Use -RP to preserve symlinks without following (avoids errors on broken symlinks)
            if cp -RP "$file" "$backup_path" 2>/dev/null; then
                ((++backed_up))
            else
                log_error "Failed to backup: $file"
                ((++failed))
            fi
        fi
    done

    if [[ $backed_up -gt 0 ]]; then
        log_ok "Backed up $backed_up files to $backup_dir"
    fi

    if [[ $failed -gt 0 ]]; then
        return 1
    fi
}
