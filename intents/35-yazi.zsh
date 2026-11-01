id=yazi
title="yazi"
why="Terminal file manager, also opened from Neovim with <C-g>. Its plugins and theme are in the repo."
requires=(core-cli)
packages=(
  "brew yazi"
  "brew zoxide"
  "cask font-symbols-only-nerd-font"
  "repo yazi/ → ~/.config/yazi (plugins and the nightfly flavor included)"
)
targets=($HOME/.config/yazi)

apply() {
  install_packages || return 1
  link yazi $HOME/.config/yazi
}
