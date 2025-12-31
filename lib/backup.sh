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
        if [[ -e "$file" || -L "$file" ]]; then
            if [[ -L "$file" ]]; then
                # It's a symlink - check if it's managed by stow (points into dotfiles)
                local target
                target=$(readlink -f "$file" 2>/dev/null || echo "")
                if [[ "$target" != *"$DOTFILES_DIR"* ]]; then
                    return 0
                fi
            else
                # It's a regular file/directory
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

    log_warn "Existing config files found. Creating backup at $backup_dir"
    mkdir -p "$backup_dir"

    for file in "${files[@]}"; do
        if [[ -e "$file" || -L "$file" ]]; then
            local should_backup=false

            if [[ -L "$file" ]]; then
                local target
                target=$(readlink -f "$file" 2>/dev/null || echo "")
                if [[ "$target" != *"$DOTFILES_DIR"* ]]; then
                    should_backup=true
                fi
            else
                should_backup=true
            fi

            if $should_backup; then
                local backup_path
                backup_path="$backup_dir/$(basename "$file")"
                if [[ -L "$file" ]]; then
                    log_info "  Backing up symlink: $file -> $backup_path"
                    # For symlinks, copy the target content
                    cp -rL "$file" "$backup_path" 2>/dev/null || cp -r "$file" "$backup_path"
                else
                    log_info "  Backing up: $file -> $backup_path"
                    cp -r "$file" "$backup_path"
                fi
            fi
        fi
    done

    echo ""
    log_info "Backup complete. Restore with: cp -r \"$backup_dir\"/* ~/"
    echo ""
}

# Restore from a backup directory
# Usage: restore_backup /path/to/.dotfiles-backup-YYYYMMDD-HHMMSS
restore_backup() {
    local backup_dir="$1"

    if [[ ! -d "$backup_dir" ]]; then
        log_error "Backup directory not found: $backup_dir"
        return 1
    fi

    log_info "Restoring from $backup_dir..."

    for file in "$backup_dir"/*; do
        if [[ -e "$file" ]]; then
            local filename
            filename=$(basename "$file")
            local target="$HOME/$filename"

            # Remove existing file/symlink first
            if [[ -e "$target" || -L "$target" ]]; then
                log_info "  Removing: $target"
                rm -rf "$target"
            fi

            log_info "  Restoring: $filename"
            cp -r "$file" "$target"
        fi
    done

    log_info "Restore complete!"
}

# List available backups
list_backups() {
    local backups
    backups=$(find "$HOME" -maxdepth 1 -type d -name ".dotfiles-backup-*" 2>/dev/null | sort -r)

    if [[ -z "$backups" ]]; then
        log_info "No backups found"
        return
    fi

    log_info "Available backups:"
    echo "$backups" | while read -r backup; do
        echo "  $backup"
    done
}
