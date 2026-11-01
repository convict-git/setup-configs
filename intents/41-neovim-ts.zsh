id=neovim-ts
title="Neovim · TypeScript/JavaScript"
why="tsgo (the native TypeScript language server) plus coc's tsserver, eslint and prettier extensions."
requires=(neovim)
# Pinned like the plugins in lazy-lock.json: preview builds change daily, and
# coc-settings.json starts it as `tsgo --lsp --stdio`
typeset -g TSGO_VERSION=7.0.0-dev.20260707.2
packages=(
  "npm @typescript/native-preview@$TSGO_VERSION (tsgo) → ~/.local"
  "coc coc-tsserver, coc-eslint, coc-prettier"
)
hosts=(registry.npmjs.org)

apply() {
  local pkg=$HOME/.local/lib/node_modules/@typescript/native-preview/package.json done=0
  [[ -x $HOME/.local/bin/tsgo && -f $pkg &&
     $(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' $pkg | head -1) == $TSGO_VERSION ]] && done=1
  task "npm" "Install tsgo (@typescript/native-preview@$TSGO_VERSION) into ~/.local" $done \
    $BREW_PREFIX/bin/npm install --global --prefix $HOME/.local @typescript/native-preview@$TSGO_VERSION
}
