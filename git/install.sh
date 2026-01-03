#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
# Custom lazygit installation
# =============================================================================
# macOS uses deps.darwin (brew), Linux uses GitHub releases
# =============================================================================

# shellcheck source=lib/install-helpers.sh
source "${BASH_SOURCE%/*}/../lib/install-helpers.sh"

install_git() {
    if is_linux; then
        local arch os tmp_archive tmp_dir version asset_name
        arch=$(get_arch_string)
        os=$(get_os_string)
        tmp_dir="${DOTFILES_TEMP_DIR:-/tmp}"
        tmp_archive="$tmp_dir/lazygit.tar.gz"

        log_step "Fetching latest lazygit version..."
        version=$(get_github_latest_version "jesseduffield/lazygit")
        if [[ -z "$version" ]]; then
            log_error "Failed to fetch latest version"
            return 1
        fi
        # Strip 'v' prefix for asset name
        version="${version#v}"

        asset_name="lazygit_${version}_${os}_${arch}.tar.gz"

        log_step "Downloading lazygit ${version}..."
        if ! download_github_release "jesseduffield/lazygit" "$asset_name" "$tmp_archive"; then
            return 1
        fi

        log_step "Extracting lazygit..."
        if ! extract_archive "$tmp_archive" "$tmp_dir" "lazygit"; then
            cleanup_temp "$tmp_archive"
            return 1
        fi

        log_step "Installing to ${DOTFILES_BIN_DIR:-/usr/local/bin}/lazygit..."
        install_binary "$tmp_dir/lazygit" "lazygit"
        cleanup_temp "$tmp_archive"
    fi
}
