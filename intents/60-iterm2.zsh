id=iterm2
title="iTerm2"
why="iTerm2, loading its settings from (and saving them back to) the repo's iterm2/ folder."
works_best_with=(deimos-font)
packages=(
  "cask iterm2 (skipped when iTerm2 is already installed)"
  "cask font-meslo-for-powerlevel10k"
  "cask font-source-code-pro"
  "repo iterm2/ as iTerm2's settings folder"
)
cask_apps=(iterm2 iTerm.app)

available() {
  cask_present iterm2 || brew_usable && return 0
  WHY_NOT="iTerm2 isn't installed and $(brew_why_not)"
  return 1
}

apply() {
  if brew_usable; then
    install_packages || return 1
  else
    caution "$(brew_why_not), so the Meslo and Source Code Pro fonts aren't installed"
  fi
  local folder=$ROOT/iterm2 done=0
  [[ $(defaults read com.googlecode.iterm2 PrefsCustomFolder 2>/dev/null) == $folder &&
     $(defaults read com.googlecode.iterm2 LoadPrefsFromCustomFolder 2>/dev/null) == 1 ]] && done=1
  # A running iTerm2 would write its current settings over the repo's when it quits
  if (( ! done )) && pgrep -xq iTerm2; then
    caution "iTerm2 is open, so its settings folder isn't changed. Quit iTerm2 and run ./install.sh again from Terminal."
    return 0
  fi
  # iTerm2 copies the repo's settings over its own when it next starts, so its
  # own are exported first; --unlink offers to import them again
  if (( ! done )) && defaults read com.googlecode.iterm2 >/dev/null 2>&1; then
    task "iTerm2" "Save iTerm2's current settings to $(tildify $BACKUP_DIR)" 0 iterm_export_prefs || return 1
  fi
  task "iTerm2" "Load iTerm2's settings from $(tildify $folder)" $done iterm_use_repo_folder
}

iterm_export_prefs() {
  run mkdir -p $BACKUP_DIR &&
    run defaults export com.googlecode.iterm2 $BACKUP_DIR/com.googlecode.iterm2.plist
}

iterm_use_repo_folder() {
  run defaults write com.googlecode.iterm2 PrefsCustomFolder -string $ROOT/iterm2 &&
    run defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true &&
    run defaults write com.googlecode.iterm2 NoSyncNeverRemindPrefsChangesLostForFile -bool true &&
    run defaults write com.googlecode.iterm2 NoSyncNeverRemindPrefsChangesLostForFile_selection -int 2
}
