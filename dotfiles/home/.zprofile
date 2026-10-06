# ~/.zprofile: User specific environment for login shells
# Ensure consistent PATH across all login and desktop sessions

typeset -U path
path=(
  "$HOME/.local/bin"
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
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"
