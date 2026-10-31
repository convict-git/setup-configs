```
ln -s vscode/keybindings.json ~/Library/Application\ Support/Cursor/User/keybindings.json
ln -s vscode/settings.json.json ~/Library/Application\ Support/Cursor/User/settings.json
```

iTerm2 can't be symlinked (macOS replaces a symlinked plist with a regular file on save), so point it at `iterm2/` instead. It loads from there on launch and writes changes back automatically:
```
defaults write com.googlecode.iterm2 PrefsCustomFolder -string ~/convict/open-source/setup-configs/iterm2
defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
defaults write com.googlecode.iterm2 NoSyncNeverRemindPrefsChangesLostForFile -bool true
defaults write com.googlecode.iterm2 NoSyncNeverRemindPrefsChangesLostForFile_selection -int 2
```
