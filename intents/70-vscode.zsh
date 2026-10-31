id=vscode
title="VS Code / Cursor"
why="Settings, keybindings and the Vim extension's .vscodevimrc, linked into whichever of VS Code and Cursor is installed."
works_best_with=(deimos-font)
packages=(
  "repo vscode/settings.json and vscode/keybindings.json → each editor's User folder"
  "repo vscode/.vscodevimrc → ~/.vscodevimrc"
  "cask font-red-hat-mono"
)
targets=(
  "$HOME/Library/Application Support/Code/User/settings.json"
  "$HOME/Library/Application Support/Code/User/keybindings.json"
  "$HOME/Library/Application Support/Cursor/User/settings.json"
  "$HOME/Library/Application Support/Cursor/User/keybindings.json"
  $HOME/.vscodevimrc
)

# Sets $reply to the User folders of the editors that are installed
vscode_user_dirs() {
  local app support
  reply=()
  for app support in "Visual Studio Code" Code Cursor Cursor; do
    [[ -d /Applications/$app.app || -d $HOME/Applications/$app.app ]] &&
      reply+="$HOME/Library/Application Support/$support/User"
  done
}

available() {
  vscode_user_dirs
  (( $#reply )) && return 0
  WHY_NOT="neither VS Code nor Cursor is installed"
  return 1
}

apply() {
  local dir
  if brew_usable; then
    install_packages || return 1
  else
    caution "$(brew_why_not), so the Red Hat Mono font isn't installed"
  fi
  vscode_user_dirs
  for dir in $reply; do
    link vscode/settings.json $dir/settings.json || return 1
    link vscode/keybindings.json $dir/keybindings.json || return 1
  done
  link vscode/.vscodevimrc $HOME/.vscodevimrc
}
