id=git-config
title="Git config"
why="Your name and email, plus shared settings: nvimdiff for diffs and merges, main as the default branch."
works_best_with=(neovim)
packages=(
  "repo git/base.gitconfig, included from ~/.gitconfig (which stays your own file)"
)

ask() {
  # What ~/.gitconfig has now wins; saved answers only fill in what it lacks, so
  # a rerun doesn't undo a later git config --global change
  local name=$(gitconfig_get user.name) email=$(gitconfig_get user.email)
  name=${name:-${ANS[git_name]}} email=${email:-${ANS[git_email]}}
  if (( ! NONINTERACTIVE )); then
    ask_text name "Your name for git commits" $name
    ask_text email "Your email for git commits" $email
  fi
  ANS[git_name]=$name ANS[git_email]=$email
  [[ -n $name && -n $email ]] || info "Left empty: set them later with git config --global user.name/user.email"
}

apply() {
  gitconfig_set_user "${ANS[git_name]}" "${ANS[git_email]}" || return 1
  gitconfig_include git/base.gitconfig || return 1
  [[ $MODE == plan ]] && return 0
  detect_git
  [[ -n ${SYS[git]} ]] || caution "git isn't installed yet; your git config applies once the Command Line Tools are"
  return 0
}
