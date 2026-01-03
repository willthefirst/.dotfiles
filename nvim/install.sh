#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Custom neovim installation
# =============================================================================
# Uses brew on macOS, appimage on Linux for latest version
# =============================================================================

# shellcheck source=lib/install-helpers.sh
source "${BASH_SOURCE%/*}/../lib/install-helpers.sh"

install_nvim() {
    if is_macos; then
        pkg_installed neovim || pkg_install neovim >/dev/null 2>&1
    elif is_linux; then
        local arch tmp_file asset_name
        arch=$(get_arch_string)
        tmp_file="${DOTFILES_TEMP_DIR:-/tmp}/nvim.appimage"
        asset_name="nvim-linux-${arch}.appimage"

        log_step "Downloading neovim appimage..."
        if ! download_github_latest "neovim/neovim" "$asset_name" "$tmp_file"; then
            return 1
        fi

        log_step "Installing to ${DOTFILES_BIN_DIR:-/usr/local/bin}/nvim..."
        install_binary "$tmp_file" "nvim"
    fi
}
