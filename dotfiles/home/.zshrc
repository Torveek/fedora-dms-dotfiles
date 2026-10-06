# -------------------------------------------------------------------
# Environment & PATH Configuration (Loaded before plugins and themes)
# -------------------------------------------------------------------
typeset -U path
path=(
  "$HOME/.local/bin"
  "/usr/local/bin"
  "/usr/local/sbin"
  "/home/linuxbrew/.linuxbrew/bin"
  "/home/linuxbrew/.linuxbrew/sbin"
  "$HOME/.linuxbrew/bin"
  "$HOME/.linuxbrew/sbin"
  "$HOME/.local/share/pnpm"
  "$HOME/.npm-global/bin"
  "$HOME/.yarn/bin"
  "$HOME/.yarn/global/node_modules/.bin"
  "$HOME/go/bin"
  "$HOME/.deno/bin"
  "$HOME/.cargo/bin"
  "/var/lib/flatpak/exports/bin"
  "$HOME/.local/share/flatpak/exports/bin"
  $path
)
export PATH

# XDG Base Directory specification
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load.
# Leaving ZSH_THEME empty allows Starship to handle the prompt.
# If you ever want a classic OMZ theme, set e.g. ZSH_THEME="robbyrussell"
# and comment out the Starship init block below.
ZSH_THEME=""

# OMZ update settings
zstyle ':omz:update' mode auto
zstyle ':omz:update' frequency 13

# zsh-command-time configuration
ZSH_COMMAND_TIME_MIN_SECONDS=3
ZSH_COMMAND_TIME_MSG="took %s"
ZSH_COMMAND_TIME_COLOR="yellow"
ZSH_COMMAND_TIME_EXCLUDE=(vim nvim mcedit)

# Plugins to load (zsh-syntax-highlighting must be last)
plugins=(
  git
  zoxide
  sudo
  command-time
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"

# Default editor
if command -v nvim >/dev/null 2>&1; then
  export EDITOR=nvim
  export VISUAL=nvim
elif command -v vim >/dev/null 2>&1; then
  export EDITOR=vim
  export VISUAL=vim
fi

# Colored manpages & terminal output
export CLICOLOR=1
export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'

# -------------------------------------------------------------------
# Aliases & Functions
# -------------------------------------------------------------------
if [ -f "$HOME/.zsh_aliases" ]; then
  source "$HOME/.zsh_aliases"
fi

# Keybinding: Ctrl+F runs 'zi' (zoxide interactive search)
if command -v zoxide >/dev/null 2>&1; then
  zoxide_interactive_widget() {
    BUFFER="zi"
    zle accept-line
  }
  zle -N zoxide_interactive_widget
  bindkey '^F' zoxide_interactive_widget
fi

# -------------------------------------------------------------------
# Interactive Startup
# -------------------------------------------------------------------
# Display fastfetch on interactive shell start
if [[ -o interactive ]] && command -v fastfetch >/dev/null 2>&1; then
  fastfetch
fi

# Initialize Starship prompt
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
else
  # Fallback prompt if Starship is unavailable
  PROMPT='%F{cyan}%n%f %F{blue}%~%f %# '
fi

