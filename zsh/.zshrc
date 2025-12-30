# =============================================================================
# .zshrc - Base Shell Configuration
# =============================================================================
# This is a portable base config. Work-specific settings are loaded from
# ~/.zshrc.work if present (managed by dotfiles-stripe overlay).
# =============================================================================

# -----------------------------------------------------------------------------
# Oh My Zsh Setup
# -----------------------------------------------------------------------------
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"

# Plugins - add wisely, as too many plugins slow down shell startup
plugins=(git)

source $ZSH/oh-my-zsh.sh

# -----------------------------------------------------------------------------
# Shell Tools
# -----------------------------------------------------------------------------

# Zoxide - smarter cd command
if command -v zoxide &> /dev/null; then
  eval "$(zoxide init zsh)"
fi

# Pure theme (if installed via Homebrew)
if command -v brew &> /dev/null && [[ -d "$(brew --prefix)/share/zsh/site-functions" ]]; then
  fpath+=("$(brew --prefix)/share/zsh/site-functions")
  autoload -U promptinit; promptinit
  if (( $+functions[prompt_pure_setup] )); then
    prompt pure
  fi
fi

# -----------------------------------------------------------------------------
# Completions
# -----------------------------------------------------------------------------
autoload -Uz compinit; compinit
autoload -Uz bashcompinit; bashcompinit

# -----------------------------------------------------------------------------
# Environment Variables
# -----------------------------------------------------------------------------
# export EDITOR='nvim'
# export LANG=en_US.UTF-8

# -----------------------------------------------------------------------------
# PATH
# -----------------------------------------------------------------------------
# Add RVM to PATH for scripting
export PATH="$PATH:$HOME/.rvm/bin"

# -----------------------------------------------------------------------------
# Aliases
# -----------------------------------------------------------------------------
# alias ll='ls -la'
# alias vim='nvim'

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
# Add custom functions here

# =============================================================================
# Work Overlay - Load work-specific config if present
# =============================================================================
# This allows work dotfiles to extend/override settings without modifying
# this file. The work overlay is optional - config works without it.
if [[ -f ~/.zshrc.work ]]; then
  source ~/.zshrc.work
fi
