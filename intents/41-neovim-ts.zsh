id=neovim-ts
title="Neovim · TypeScript/JavaScript"
why="tsgo (the native TypeScript language server) plus coc's tsserver, eslint and prettier extensions."
requires=(neovim)
packages=(
  "npm @typescript/native-preview (tsgo) → ~/.local"
  "coc coc-tsserver, coc-eslint, coc-prettier"
)
hosts=(registry.npmjs.org)

apply() {
  local done=0
  [[ -x $HOME/.local/bin/tsgo ]] && done=1
  task "npm" "Install tsgo (@typescript/native-preview) into ~/.local" $done \
    $BREW_PREFIX/bin/npm install --global --prefix $HOME/.local @typescript/native-preview
}
