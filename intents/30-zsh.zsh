id=zsh
title="zsh"
why="oh-my-zsh with the cypher theme, plus autosuggestions, syntax highlighting, vi mode and history search."
requires=(core-cli)
packages=(
  "git ohmyzsh/ohmyzsh at 97e1105 → ~/.oh-my-zsh (auto-update off)"
  "brew zsh-autosuggestions"
  "brew zsh-syntax-highlighting"
  "brew zsh-vi-mode"
  "brew zsh-history-substring-search"
  "repo zsh/.zshrc → ~/.zshrc"
)
hosts=(github.com)
targets=($HOME/.zshrc)

ZSH_OMZ_COMMIT=97e11051e2f8053b1d694788d1cb4b0dbb1e2365

apply() {
  install_packages || return 1
  git_clone_pinned https://github.com/ohmyzsh/ohmyzsh.git $ZSH_OMZ_COMMIT $HOME/.oh-my-zsh master || return 1
  link zsh/.zshrc $HOME/.zshrc || return 1
  local shell=$(dscl . -read /Users/$(id -un) UserShell 2>/dev/null | awk '$1 == "UserShell:" {print $2}')
  [[ -z $shell || $shell == */zsh ]] || caution "Your login shell is $shell; switch with: chsh -s /bin/zsh"
  return 0
}
