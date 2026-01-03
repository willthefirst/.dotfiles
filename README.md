# Dotfiles

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/).

## What's Included

- **zsh** - Shell config
- **git** - Git config with conditional commit signing (1Password SSH for personal repos)
- **nvim** - Neovim config
- **ssh** - SSH config with 1Password agent
- **ghostty** - Terminal config

## Install

```bash
# Requires stow: brew install stow (macOS) or apt install stow (Ubuntu)

git clone https://github.com/willthefirst/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

Use `--force` to remove conflicts, or `--adopt` to keep existing file contents.

## Usage

```bash
make configure      # Configure dotfiles (symlinks)
make uninstall      # Remove symlinks
make test           # Run tests
make validate       # Check config syntax
```

## Adding New Configs

1. Create package: `mkdir ~/.dotfiles/newapp`
2. Mirror the home directory structure inside it
3. Add to `PACKAGE_CONFIG` in `lib/config.sh`
4. Run `./install.sh`

## License

MIT
