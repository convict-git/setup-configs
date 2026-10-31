id=core-cli
title="Core CLI"
why="Fast file and text search used by the shell, Neovim, yazi and the git aliases."
requires=(foundation)
packages=(
  "brew fd"
  "brew ripgrep"
  "brew fzf"
  "brew bat"
  "repo scripts/fd-cache.sh → ~/.local/bin/fd-cache (fd with a 1-minute cache)"
)
targets=($HOME/.local/bin/fd-cache)

available() { brew_usable || { WHY_NOT=$(brew_why_not); return 1 } }

apply() {
  install_packages || return 1
  link scripts/fd-cache.sh $HOME/.local/bin/fd-cache
}
