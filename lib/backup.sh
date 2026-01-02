#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Backup logic for dotfiles
# =============================================================================

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
# Usage: create_backup file1 file2 ...
create_backup() {
    local files=("$@")
    local backup_dir
    backup_dir="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

    if ! needs_backup "${files[@]}"; then
        return 0
    fi

    if [[ "${FORCE_MODE:-false}" == "true" ]]; then
        return 0
    fi

    mkdir -p "$backup_dir"

    local backed_up=0
    for file in "${files[@]}"; do
        if file_or_link_exists "$file" && ! is_dotfiles_managed "$file"; then
            local backup_path
            backup_path="$backup_dir/$(basename "$file")"
            # Use -RP to preserve symlinks without following (avoids errors on broken symlinks)
            cp -RP "$file" "$backup_path" 2>/dev/null || true
            ((backed_up++))
        fi
    done

    if [[ $backed_up -gt 0 ]]; then
        echo "✓ Backed up $backed_up files to $backup_dir"
    fi
}

# Restore from a backup directory
# Usage: restore_backup /path/to/.dotfiles-backup-YYYYMMDD-HHMMSS
restore_backup() {
    local backup_dir="$1"

    if [[ ! -d "$backup_dir" ]]; then
        log_error "Backup directory not found: $backup_dir"
        return 1
    fi

    local restored=0
    for file in "$backup_dir"/*; do
        if [[ -e "$file" ]]; then
            local filename
            filename=$(basename "$file")
            local target="$HOME/$filename"

            # Remove existing file/symlink first
            file_or_link_exists "$target" && rm -rf "$target"
            cp -r "$file" "$target"
            ((restored++))
        fi
    done

    echo "✓ Restored $restored files from $backup_dir"
}

# List available backups
list_backups() {
    local backups
    backups=$(find "$HOME" -maxdepth 1 -type d -name ".dotfiles-backup-*" 2>/dev/null | sort -r)

    if [[ -z "$backups" ]]; then
        echo "No backups found"
        return
    fi

    echo "Available backups:"
    echo "$backups" | while read -r backup; do
        echo "  $backup"
    done
}
