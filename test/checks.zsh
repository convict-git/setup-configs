#!/bin/zsh
# Runs inside a sandbox VM after install.sh, as the user it ran as.
# Usage: checks.zsh <scenario>. Prints one line per check; exits 1 if any failed.

emulate zsh
setopt extended_glob

scenario=$1
ROOT=${0:A:h:h}
B=/opt/homebrew
failures=0
# What a new shell from ~/.zshrc would have; SSH commands start with less
path=($HOME/.local/bin $B/bin $B/opt/rustup/bin $path)

pass() { print -r -- "  ✓ $1" }
check() {  # check <description> <command...>
  local what=$1; shift
  if "$@" >/dev/null 2>&1; then print -r -- "  ✓ $what"; else print -r -- "  ✗ $what"; (( failures++ )); fi
}
links_into_repo() { [[ -L $1 && ${1:A} == $ROOT/* ]] }
no_clt_dialog() { ! pgrep -f "Install Command Line Developer Tools" }
gitconfig_has() { grep -qF -- $1 $HOME/.gitconfig }
# The old link went into the backup as it was, and --unlink knows about it
old_link_backed_up() {
  local backup=($HOME/.setup-configs-backup/*/.gitconfig(N@))
  (( $#backup )) && [[ $(readlink $backup[1]) == $ROOT/git/.gitconfig ]] &&
    grep -qxF -- $HOME/.gitconfig ${backup[1]:h}/.manifest
}

print "Checks for $scenario"
check "Apple's install dialog for the Command Line Tools never opened" no_clt_dialog
check "A log was written" test -n "$(print $HOME/.local/state/setup-configs/*.log(N))"
check "Answers were saved" test -f $HOME/.config/setup-configs/answers.env
check "Deimos is in ~/Library/Fonts" test -f $HOME/Library/Fonts/DeimosRegular2.ttf
check "~/.gitconfig has the name" gitconfig_has "Sandbox Tester"
check "~/.gitconfig includes git/base.gitconfig" gitconfig_has "$ROOT/git/base.gitconfig"

if [[ -x /Library/Developer/CommandLineTools/usr/bin/git ]]; then
  check "git reads the name through ~/.gitconfig" test "$(git config --global user.name)" = "Sandbox Tester"
  check "git sees the base settings (merge.tool)" test "$(git config merge.tool)" = nvimdiff
fi

if [[ $scenario == (fresh-sudo|brew-own) ]]; then
  check "Core CLI tools installed" test -e $B/opt/fd -a -e $B/opt/ripgrep -a -e $B/opt/fzf -a -e $B/opt/bat
  check "fd-cache linked" links_into_repo $HOME/.local/bin/fd-cache
  check "Git aliases included" gitconfig_has "$ROOT/git/aliases.gitconfig"
  check "git last works" git -C $ROOT last -1
  check "~/.zshrc linked" links_into_repo $HOME/.zshrc
  check "oh-my-zsh cloned" test -f $HOME/.oh-my-zsh/oh-my-zsh.sh
  check "A new zsh starts without errors" test -z "$(TERM=xterm-256color zsh -i -c exit 2>&1 >/dev/null)"
  check "nvm has a default Node.js" test -e $HOME/.nvm/alias/default
  check "~/.config/yazi linked" links_into_repo $HOME/.config/yazi
  check "yazi preview tools installed" test -e $B/opt/ffmpeg -a -e $B/opt/poppler -a -e $B/opt/chafa
  check "~/.config/nvim linked" links_into_repo $HOME/.config/nvim
  check "At least 40 Neovim plugins installed" test $(ls $HOME/.local/share/nvim/lazy | wc -l) -ge 40
  check "8 treesitter parsers built" test $(ls $HOME/.local/share/nvim/lazy/nvim-treesitter/parser/*.so | wc -l) -eq 8
  for ext in coc-json coc-tsserver coc-clangd coc-rust-analyzer; do
    check "$ext installed" test -d $HOME/.config/coc/extensions/node_modules/$ext
  done
  check "Neovim starts without messages" test -z "$($B/bin/nvim --headless "+lua io.stdout:write(vim.fn.execute('messages'))" +qa 2>&1)"
  check "tsgo runs" $HOME/.local/bin/tsgo --version
  check "clang-format runs through xcrun" $HOME/.local/bin/clang-format --version
  check "lldb-dap runs through xcrun" $HOME/.local/bin/lldb-dap --help
  check "rust-analyzer runs" $B/opt/rustup/bin/rust-analyzer --version
  check "iTerm2 installed in ~/Applications" test -d $HOME/Applications/iTerm.app
  check "iTerm2 loads settings from the repo" test "$(defaults read com.googlecode.iterm2 PrefsCustomFolder)" = $ROOT/iterm2
  check "lazy-lock.json unchanged" git -C $ROOT diff --quiet -- nvim/lazy-lock.json
elif [[ $scenario == (fresh-nosudo|brew-other) ]]; then
  check "Nothing installed with brew" test ! -e $B/opt/fd
  check "No links made for brew-based intents" test ! -L $HOME/.zshrc -a ! -L $HOME/.config/nvim
fi

case $scenario in
  declines)
    check "Core CLI tools installed" test -e $B/opt/fd -a -e $B/opt/ripgrep
    check "~/.zshrc linked" links_into_repo $HOME/.zshrc
    check "The saved answers keep iTerm2's no" grep -qx intent_iterm2=n $HOME/.config/setup-configs/answers.env
    check "iTerm2 (declined) not installed" test ! -e $HOME/Applications/iTerm.app
    check "iTerm2's settings folder (declined) not set" test -z "$(defaults read com.googlecode.iterm2 PrefsCustomFolder 2>/dev/null)"
    check "Neovim (declined) not linked" test ! -e $HOME/.config/nvim -a ! -L $HOME/.config/nvim
    check "yazi (declined) not installed" test ! -e $B/opt/yazi
    ;;
  legacy-link)
    check "~/.gitconfig is a file of its own" test -f $HOME/.gitconfig -a ! -L $HOME/.gitconfig
    check "Nothing written into the repo's git/.gitconfig" test ! -e $ROOT/git/.gitconfig -a ! -L $ROOT/git/.gitconfig
    check "The old link is in the backup and its manifest" old_link_backed_up
    check "Git aliases included" gitconfig_has "$ROOT/git/aliases.gitconfig"
    ;;
esac

print
(( failures )) && { print "$failures check(s) failed"; exit 1 }
print "All checks passed"
