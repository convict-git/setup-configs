id=nvm
title="nvm"
why="Node version manager, with the current Node.js LTS as the default (loaded by .zshrc)."
requires=(zsh)
packages=(
  "brew nvm"
  "nodejs Node.js LTS, installed by nvm into ~/.nvm"
)
hosts=(nodejs.org)

apply() {
  install_packages || return 1
  local done=0
  [[ -e $HOME/.nvm/alias/default ]] && done=1
  task "Node.js" "Install the Node.js LTS with nvm and make it the default" $done nvm_install_lts
}

nvm_install_lts() {
  run mkdir -p $HOME/.nvm &&
    run zsh -c "export NVM_DIR=\$HOME/.nvm; source $BREW_PREFIX/opt/nvm/nvm.sh && nvm install --lts --no-progress && nvm alias default 'lts/*'"
}
