# Dotfiles

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Overview

This repository contains portable, base configuration files. Work-specific settings are loaded from a separate overlay repository (`~/.dotfiles-stripe`) when present, keeping this config clean and shareable.

### Include/Source Pattern

```
~/.zshrc          ─── sources ───▶  ~/.zshrc.work (if exists)
~/.gitconfig      ─── includes ──▶  ~/.gitconfig.work (if exists)
~/.ssh/config     ─── includes ──▶  ~/.ssh/config.work (if exists)
nvim/lazy.lua     ─── imports ───▶  plugins-work/ (if exists)
```

## Structure

```
~/.dotfiles/
├── zsh/
│   └── .zshrc                 # Shell config (sources .zshrc.work)
├── git/
│   ├── .gitconfig             # Git config (includes .gitconfig.work)
│   └── .gitignore_global      # Global gitignore
├── nvim/
│   └── .config/nvim/          # Neovim config (imports plugins-work/)
├── ssh/
│   └── .ssh/config            # SSH config (includes config.work)
├── claude/
│   └── .claude/               # Claude Code settings
└── README.md
```

## Installation

### Prerequisites

```bash
# macOS
brew install stow

# Ubuntu/Debian
sudo apt install stow
```

### Quick Start

```bash
# Clone the repository
git clone https://github.com/willthefirst/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles

# Backup existing configs (optional but recommended)
./backup.sh

# Deploy all configs
stow -v -t ~ zsh git nvim ssh claude

# Or deploy individually
stow -v -t ~ zsh
stow -v -t ~ git
```

### With Work Overlay

```bash
# Clone work overlay (Stripe internal)
git clone git@git.corp.stripe.com:willm/.dotfiles-stripe.git ~/.dotfiles-stripe
cd ~/.dotfiles-stripe

# Deploy work configs (creates overlay files)
stow -v -t ~ zsh git nvim ssh claude
```

## How GNU Stow Works

Stow creates symlinks from your home directory to files in the repository:

```
~/.dotfiles/zsh/.zshrc  →  ~/.zshrc
~/.dotfiles/git/.gitconfig  →  ~/.gitconfig
~/.dotfiles/nvim/.config/nvim/  →  ~/.config/nvim/
```

The directory structure inside each "package" (zsh/, git/, etc.) mirrors where files should appear relative to the target directory (~).

## Making Changes

### Base Config Changes

```bash
cd ~/.dotfiles

# Edit configs directly (they're symlinked)
nvim ~/.zshrc

# Commit and push
git add -A
git commit -m "Update zsh config"
git push
```

### Work Overlay Changes

```bash
cd ~/.dotfiles-stripe

# Edit work configs
nvim ~/.zshrc.work

# Commit and push
git add -A
git commit -m "Update Stripe aliases"
git push
```

## Updating

```bash
# Update base dotfiles
cd ~/.dotfiles
git pull

# Update work overlay
cd ~/.dotfiles-stripe
git pull
```

## Uninstalling

```bash
# Remove symlinks (keeps files in repo)
cd ~/.dotfiles
stow -D -t ~ zsh git nvim ssh claude

# Remove work overlay symlinks
cd ~/.dotfiles-stripe
stow -D -t ~ zsh git nvim ssh claude
```

## Adding New Configs

1. Create package directory: `mkdir -p ~/.dotfiles/newapp`
2. Add config with correct path structure:
   ```bash
   # For ~/.newapprc
   touch ~/.dotfiles/newapp/.newapprc

   # For ~/.config/newapp/config
   mkdir -p ~/.dotfiles/newapp/.config/newapp
   touch ~/.dotfiles/newapp/.config/newapp/config
   ```
3. Deploy: `stow -v -t ~ newapp`
4. Add work overlay support (edit file to source/include overlay if needed)

## Best Practices

1. **Keep base portable** - No machine-specific or work-specific code in base configs
2. **Conditional loading** - Always check if overlay files exist before sourcing
3. **Comment your overlays** - Document what each section does
4. **Test changes** - Source files or restart shell to test before committing
5. **Don't store secrets** - Use environment variables or secure vaults

## Troubleshooting

### Stow conflicts with existing files

```bash
# Backup and remove existing file
mv ~/.zshrc ~/.zshrc.backup
stow -v -t ~ zsh
```

### Symlink not working

```bash
# Check if symlink exists
ls -la ~/.zshrc

# Re-stow (remove and add)
cd ~/.dotfiles
stow -D -t ~ zsh && stow -v -t ~ zsh
```

### Work overlay not loading

```bash
# Check if overlay file exists
ls -la ~/.zshrc.work

# Check if work dotfiles are stowed
cd ~/.dotfiles-stripe
stow -v -t ~ zsh
```

## License

MIT
