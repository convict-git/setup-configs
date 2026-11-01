id=neovim
title="Neovim"
why="Neovim with coc.nvim, Telescope, treesitter and about 40 plugins, all at the versions in nvim/lazy-lock.json."
requires=(core-cli)
works_best_with=(deimos-font)
packages=(
  "brew neovim"
  "brew node (runs coc.nvim)"
  "brew cmake (builds telescope-fzf-native)"
  "cask font-symbols-only-nerd-font"
  "repo nvim/ → ~/.config/nvim"
  "lazy plugins pinned in nvim/lazy-lock.json"
  "treesitter c, cpp, rust, typescript, tsx, javascript, markdown, markdown_inline"
  "coc coc-json, coc-yaml, coc-sh, coc-git, coc-floaterm, coc-docker, coc-cmake, coc-emmet"
)
hosts=(github.com codeload.github.com registry.npmjs.org)
targets=($HOME/.config/nvim)

apply() {
  install_packages || return 1
  link nvim $HOME/.config/nvim
}

# Runs after the TS/JS, C/C++ and Rust intents, since which plugins and coc
# extensions get installed depends on the tools those put on PATH
finish() {
  local lazy_dir=${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy/lazy.nvim done=0
  local lazy_commit=$(sed -n 's/.*"lazy.nvim": {.*"commit": "\([0-9a-f]*\)".*/\1/p' $ROOT/nvim/lazy-lock.json)
  [[ -e $lazy_dir ]] && done=1
  # init.lua would clone lazy.nvim's latest release, and lazy.nvim doesn't restore itself
  task "Neovim" "Install lazy.nvim at ${lazy_commit[1,7]}, the version in lazy-lock.json" $done \
    nvim_install_lazy $lazy_dir $lazy_commit || return 1
  task "Neovim" "Install plugins at the versions in lazy-lock.json" 0 nvim_headless "+Lazy! restore" || return 1
  task "Neovim" "Build the treesitter parsers" 0 nvim_headless || return 1
  task "Neovim" "Install coc extensions" 0 nvim_install_coc || return 1
  task "Neovim" "Check that Neovim starts without errors" 0 nvim_check
}

# Built next to its folder and moved in once checked out, like git_clone_pinned
nvim_install_lazy() {
  local dir=$1 commit=$2 tmp=$1.setup-configs-partial
  detect_git
  [[ -e $tmp ]] && { run rm -rf ${tmp:?} || return 1 }
  run ${SYS[git]} clone -q --filter=blob:none https://github.com/folke/lazy.nvim.git $tmp &&
    run ${SYS[git]} -C $tmp checkout -q $commit &&
    run mv $tmp $dir || { [[ $MODE == dry ]] || rm -rf ${tmp:?}; return 1 }
}

nvim_headless() {
  run env SETUP_CONFIGS_HEADLESS=1 $BREW_PREFIX/bin/nvim --headless "$@" +qa
}

nvim_install_coc() {
  nvim_headless "+lua vim.cmd('CocInstall -sync ' .. table.concat(vim.g.coc_global_extensions, ' '))"
}

nvim_check() {
  [[ $MODE == dry ]] && { nvim_headless "+lua io.stdout:write(vim.fn.execute('messages'))"; return 0 }
  local out=$($BREW_PREFIX/bin/nvim --headless "+lua io.stdout:write(vim.fn.execute('messages'))" +qa 2>&1)
  if print -r -- $out | grep -qE 'E[0-9]+:|Error|error'; then
    print -r -- $out | while IFS= read -r line; do detail "│ $line"; done
    caution "Neovim printed errors on start; open it and run :messages"
    return 0
  fi
  ok "Neovim starts cleanly"
}
