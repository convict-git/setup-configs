id=deimos-font
title="Deimos font"
why="The monospace font iTerm2, VS Code and Neovim's GUI are set to."
packages=(
  "repo fonts/DeimosRegular2.ttf → ~/Library/Fonts (copied; apps pick it up after a restart)"
)

apply() {
  copy_file fonts/DeimosRegular2.ttf $HOME/Library/Fonts/DeimosRegular2.ttf
}
