#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# lib/install-helpers.sh - Helper functions for installing from external sources
# =============================================================================
# Dependencies: log.sh
# Provides: get_arch_string, get_os_string, cleanup_temp, download_file,
#           get_github_latest_version, download_github_release,
#           download_github_latest, extract_archive, install_binary
# =============================================================================

# Source guard - prevent multiple loading
[[ -n "${_DOTFILES_INSTALL_HELPERS_LOADED:-}" ]] && return 0
_DOTFILES_INSTALL_HELPERS_LOADED=1

# shellcheck source=lib/log.sh
source "${BASH_SOURCE%/*}/log.sh"

# Get architecture string for downloads
# Usage: get_arch_string
# Output: "x86_64", "arm64", etc.
get_arch_string() {
    local arch
    arch=$(uname -m)

    case "$arch" in
        x86_64|amd64) echo "x86_64" ;;
        aarch64|arm64) echo "arm64" ;;
        *) echo "$arch" ;;
    esac
}

# Get OS string for downloads
# Usage: get_os_string
# Output: "Linux", "Darwin", etc.
get_os_string() {
    uname -s
}

# Cleanup temporary files
# Usage: cleanup_temp <file1> [file2] ...
cleanup_temp() {
    for file in "$@"; do
        [[ -e "$file" ]] && rm -rf "$file"
    done
}

# Download a file from URL to destination
# Usage: download_file <url> <destination>
download_file() {
    local url="$1"
    local dest="$2"

    if ! curl -fsSL -o "$dest" "$url"; then
        log_error "Failed to download: $url"
        return 1
    fi
}

# Get latest release version from GitHub API
# Usage: get_github_latest_version <owner/repo>
# Output: version string (e.g., "v1.2.3")
get_github_latest_version() {
    local repo="$1"
    local api_url="https://api.github.com/repos/${repo}/releases/latest"

    curl -fsSL "$api_url" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/'
}

# Download file from GitHub release (latest version)
# Usage: download_github_release <owner/repo> <asset_name> <output_file>
# Example: download_github_release "jesseduffield/lazygit" "lazygit_0.40.2_Linux_x86_64.tar.gz" "/tmp/lazygit.tar.gz"
# Note: For assets using /releases/latest/download/ URL pattern, use download_github_latest instead
download_github_release() {
    local repo="$1"
    local asset_name="$2"
    local output="$3"

    local version
    version=$(get_github_latest_version "$repo") || return 1

    local download_url="https://github.com/${repo}/releases/download/${version}/${asset_name}"
    download_file "$download_url" "$output"
}

# Download file from GitHub releases/latest/download (simpler pattern)
# Usage: download_github_latest <owner/repo> <asset_name> <output_file>
# Example: download_github_latest "neovim/neovim" "nvim-linux-x86_64.appimage" "/tmp/nvim.appimage"
download_github_latest() {
    local repo="$1"
    local asset_name="$2"
    local output="$3"

    local download_url="https://github.com/${repo}/releases/latest/download/${asset_name}"
    download_file "$download_url" "$output"
}

# Extract archive to directory
# Usage: extract_archive <archive_file> <destination_dir> [files_to_extract...]
extract_archive() {
    local archive="$1"
    local dest="$2"
    shift 2
    local files=("$@")

    case "$archive" in
        *.tar.gz|*.tgz)
            if ! tar -xzf "$archive" -C "$dest" "${files[@]}" 2>/dev/null; then
                log_error "Failed to extract: $archive"
                return 1
            fi
            ;;
        *.tar.bz2)
            if ! tar -xjf "$archive" -C "$dest" "${files[@]}" 2>/dev/null; then
                log_error "Failed to extract: $archive"
                return 1
            fi
            ;;
        *.zip)
            if ! unzip -q "$archive" -d "$dest" "${files[@]}" 2>/dev/null; then
                log_error "Failed to extract: $archive"
                return 1
            fi
            ;;
        *)
            log_error "Unknown archive format: $archive"
            return 1
            ;;
    esac
}

# Install binary to system path
# Usage: install_binary <source> <name> [destination_dir]
# Default destination: $DOTFILES_BIN_DIR (falls back to /usr/local/bin)
install_binary() {
    local source="$1"
    local name="$2"
    local dest_dir="${3:-${DOTFILES_BIN_DIR:-/usr/local/bin}}"

    chmod +x "$source"

    if [[ -w "$dest_dir" ]]; then
        mv "$source" "$dest_dir/$name"
    else
        sudo mv "$source" "$dest_dir/$name"
    fi

    log_ok "Installed $name to $dest_dir"
}
