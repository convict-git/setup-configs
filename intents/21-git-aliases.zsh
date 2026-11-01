id=git-aliases
title="Git aliases"
why="Shortcuts like git s, git b, git last and git cam, and the missing-changes script."
requires=(core-cli)
packages=(
  "repo git/aliases.gitconfig, included from ~/.gitconfig"
  "repo scripts/missing-changes.sh → ~/.local/bin/missing-changes"
)
targets=($HOME/.local/bin/missing-changes)

apply() {
  gitconfig_include git/aliases.gitconfig || return 1
  link scripts/missing-changes.sh $HOME/.local/bin/missing-changes
}
