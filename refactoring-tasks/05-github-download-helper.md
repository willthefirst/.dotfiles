# Task: Extract GitHub Download Pattern to Shared Helper

## Branch Name
`refactor/github-download-helper`

## Problem Statement
The pattern for downloading binaries from GitHub releases is duplicated across package installers with similar logic for fetching, extracting, and installing.

### Current Duplication

**In `nvim/install.sh` (lines 22-29):**
```bash
curl -fsSL -o /tmp/nvim.appimage "$nvim_url"
chmod +x /tmp/nvim.appimage
sudo mv /tmp/nvim.appimage /usr/local/bin/nvim
```

**In `git/install.sh` (lines 22-43):**
```bash
version=$(curl -fsSL "https://api.github.com/repos/...releases/latest" | grep '"tag_name"')
curl -fsSL "$lazygit_url" -o /tmp/lazygit.tar.gz
tar -xzf /tmp/lazygit.tar.gz -C /tmp lazygit
sudo mv /tmp/lazygit /usr/local/bin/lazygit
```

### Issues
1. Error handling logic duplicated
2. Cleanup of temp files handled differently (or not at all)
3. Logging inconsistent between installers
4. Architecture detection may be duplicated
5. If download pattern needs to change, multiple files need updating

## Desired Outcome
Create `lib/install-helpers.sh` with reusable functions for:
- Downloading from GitHub releases
- Extracting archives
- Installing binaries to system paths
- Proper cleanup and error handling

## Implementation Steps

### 1. Create `lib/install-helpers.sh`

```bash
#!/usr/bin/env bash
# Helper functions for installing packages from external sources

source "${BASH_SOURCE%/*}/log.sh"
source "${BASH_SOURCE%/*}/platform.sh"

# Download a file from URL to destination
# Usage: download_file <url> <destination>
download_file() {
    local url="$1"
    local dest="$2"

    log_step "Downloading from $url"
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

# Download binary from GitHub release
# Usage: download_github_release <owner/repo> <asset_pattern> <output_file>
# Example: download_github_release "jesseduffield/lazygit" "Linux_x86_64.tar.gz" "/tmp/lazygit.tar.gz"
download_github_release() {
    local repo="$1"
    local asset_pattern="$2"
    local output="$3"

    local version
    version=$(get_github_latest_version "$repo") || return 1

    local download_url="https://github.com/${repo}/releases/download/${version}/${asset_pattern}"
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
            tar -xzf "$archive" -C "$dest" "${files[@]}"
            ;;
        *.tar.bz2)
            tar -xjf "$archive" -C "$dest" "${files[@]}"
            ;;
        *.zip)
            unzip -q "$archive" -d "$dest" "${files[@]}"
            ;;
        *)
            log_error "Unknown archive format: $archive"
            return 1
            ;;
    esac
}

# Install binary to system path
# Usage: install_binary <source> <name> [destination_dir]
# Default destination: /usr/local/bin
install_binary() {
    local source="$1"
    local name="$2"
    local dest_dir="${3:-/usr/local/bin}"

    chmod +x "$source"

    if [[ -w "$dest_dir" ]]; then
        mv "$source" "$dest_dir/$name"
    else
        sudo mv "$source" "$dest_dir/$name"
    fi

    log_ok "Installed $name to $dest_dir"
}

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
```

### 2. Refactor `nvim/install.sh`

**Before:**
```bash
curl -fsSL -o /tmp/nvim.appimage "$nvim_url"
chmod +x /tmp/nvim.appimage
sudo mv /tmp/nvim.appimage /usr/local/bin/nvim
```

**After:**
```bash
source "$DOTFILES_DIR/lib/install-helpers.sh"

install_nvim_linux() {
    local arch=$(get_arch_string)
    local tmp_file="/tmp/nvim.appimage"

    # Map architecture to nvim release asset name
    local asset_name="nvim-linux-${arch}.appimage"

    download_github_release "neovim/neovim" "$asset_name" "$tmp_file" || return 1
    install_binary "$tmp_file" "nvim"
    cleanup_temp "$tmp_file"
}
```

### 3. Refactor `git/install.sh` (lazygit installation)

**Before:**
```bash
version=$(curl -fsSL "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep '"tag_name"')
curl -fsSL "$lazygit_url" -o /tmp/lazygit.tar.gz
tar -xzf /tmp/lazygit.tar.gz -C /tmp lazygit
sudo mv /tmp/lazygit /usr/local/bin/lazygit
```

**After:**
```bash
source "$DOTFILES_DIR/lib/install-helpers.sh"

install_lazygit() {
    local os=$(get_os_string)
    local arch=$(get_arch_string)
    local tmp_dir="/tmp/lazygit-install"
    local tmp_archive="/tmp/lazygit.tar.gz"

    mkdir -p "$tmp_dir"

    # Get version and construct asset name
    local version=$(get_github_latest_version "jesseduffield/lazygit")
    version="${version#v}"  # Remove 'v' prefix if present
    local asset_name="lazygit_${version}_${os}_${arch}.tar.gz"

    download_github_release "jesseduffield/lazygit" "$asset_name" "$tmp_archive" || return 1
    extract_archive "$tmp_archive" "$tmp_dir" "lazygit"
    install_binary "$tmp_dir/lazygit" "lazygit"
    cleanup_temp "$tmp_archive" "$tmp_dir"
}
```

### 4. Check for other GitHub download patterns

Search for similar patterns in other install scripts:
```bash
grep -r "curl.*github.com/.*releases" . --include="*.sh"
grep -r "api.github.com/repos" . --include="*.sh"
```

Refactor any other occurrences to use the new helpers.

### 5. Add error handling

Ensure all helper functions:
- Return non-zero on failure
- Log meaningful error messages
- Clean up temp files even on failure (use trap)

Example with trap:
```bash
install_lazygit() {
    local tmp_files=()
    trap 'cleanup_temp "${tmp_files[@]}"' EXIT

    # ... download and install ...

    trap - EXIT  # Clear trap on success
}
```

## Files to Create/Modify
- `lib/install-helpers.sh` (CREATE)
- `nvim/install.sh` (MODIFY - use new helpers)
- `git/install.sh` (MODIFY - use new helpers)
- Any other `*/install.sh` files with GitHub downloads (MODIFY)

## Testing
```bash
# Test the helper functions exist and are sourceable
source lib/install-helpers.sh && echo "OK"

# Test architecture detection
source lib/install-helpers.sh
echo "Arch: $(get_arch_string)"
echo "OS: $(get_os_string)"

# Test full install flow (requires network, careful with this)
# ./nvim/install.sh
# ./git/install.sh

# Run validation
./validate.sh
```

## Success Criteria
- [ ] `lib/install-helpers.sh` created with documented functions
- [ ] `nvim/install.sh` refactored to use helpers
- [ ] `git/install.sh` refactored to use helpers
- [ ] No duplicate download/extract/install patterns remain
- [ ] Error handling is consistent across all installers
- [ ] Temp file cleanup happens even on failure
- [ ] All package installations still work correctly
