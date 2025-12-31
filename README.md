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

### Quick Start (Base Only)

```bash
# Clone the repository
git clone https://github.com/willthefirst/.dotfiles.git ~/.dotfiles

# Create required directories
mkdir -p ~/.config ~/.ssh/sockets
chmod 700 ~/.ssh ~/.ssh/sockets

# Deploy all configs
cd ~/.dotfiles
stow -v -t ~ zsh git nvim ssh
```

### With Work Overlay

```bash
# 1. Install base dotfiles first (see above)

# 2. Clone work overlay
git clone git@git.corp.stripe.com:willm/.dotfiles-stripe.git ~/.dotfiles-stripe

# 3. Deploy work overlay configs
cd ~/.dotfiles-stripe
stow -v -t ~ zsh git ssh

# 4. Manually link nvim plugins-work (Stow can't nest into existing symlinks)
ln -sf ~/.dotfiles-stripe/nvim/.config/nvim/lua/plugins-work ~/.config/nvim/lua/plugins-work
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
# Edit configs directly (they're symlinked)
nvim ~/.zshrc

# Commit and push
cd ~/.dotfiles
git add -A && git commit -m "Update zsh config" && git push
```

### Work Overlay Changes

```bash
# Edit work configs
nvim ~/.zshrc.work

# Commit and push
cd ~/.dotfiles-stripe
git add -A && git commit -m "Update Stripe aliases" && git push
```

## Updating

```bash
# Update base dotfiles
cd ~/.dotfiles && git pull

# Update work overlay
cd ~/.dotfiles-stripe && git pull

# Reload shell
source ~/.zshrc
```

## Uninstalling

```bash
# Remove base symlinks
cd ~/.dotfiles
stow -D -t ~ zsh git nvim ssh

# Remove work overlay symlinks
cd ~/.dotfiles-stripe
stow -D -t ~ zsh git ssh
rm ~/.config/nvim/lua/plugins-work
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
4. Add overlay support by adding to the config:
   ```bash
   # For shell configs
   [[ -f ~/.newapprc.work ]] && source ~/.newapprc.work

   # For git-style configs
   [include]
       path = ~/.newapprc.work
   ```

## Best Practices

1. **Keep base portable** — No machine-specific or work-specific code
2. **Conditional loading** — Always check if overlay files exist before sourcing
3. **Don't store secrets** — Use environment variables or secure vaults
4. **Test changes** — Run `source ~/.zshrc` before committing

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

# Check if base config sources it
grep "zshrc.work" ~/.zshrc
```

### SSH not working after setup

The base SSH config excludes Stripe hosts from 1Password agent settings. If you have issues:

```bash
# Test SSH connection
ssh -vT git@git.corp.stripe.com

# Check config is correct
cat ~/.ssh/config
```

## License

MIT
